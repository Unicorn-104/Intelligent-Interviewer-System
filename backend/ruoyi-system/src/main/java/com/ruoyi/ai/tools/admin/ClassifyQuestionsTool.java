package com.ruoyi.ai.tools.admin;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.AbstractAgentTool;
import com.ruoyi.ai.core.PendingAction;
import com.ruoyi.ai.core.PendingActionHandler;
import com.ruoyi.ai.core.ToolArgs;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

/** 批量调整题目分类或题型：先出草稿，确认后才 UPDATE。 */
@Component
public class ClassifyQuestionsTool extends AbstractAgentTool implements PendingActionHandler
{
    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "classify_questions";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        props.putObject("ids").put("type", "array").put("description", "题号数组，最多 200 个")
                .putObject("items").put("type", "integer");
        params.putArray("required").add("ids");
        props.putObject("category").put("type", "integer").put("minimum", 1).put("maximum", 5);
        props.putObject("type").put("type", "integer").put("minimum", 1).put("maximum", 5);
        return toolDef("批量调整题目分类或题型（生成待确认草稿）", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        Set<Long> ids = ToolArgs.longSet(args.path("ids"));
        if (ids.isEmpty())
        {
            return ToolResult.read("没有可调整的题目：ids 为空。");
        }
        if (ids.size() > QuestionBankSupport.MAX_IDS)
        {
            return ToolResult.read("一次最多调整 " + QuestionBankSupport.MAX_IDS + " 题。");
        }
        Integer category = ToolArgs.integer(args, "category");
        Integer type = ToolArgs.integer(args, "type");
        if (category == null && type == null)
        {
            return ToolResult.read("请至少给出目标分类 category 或目标题型 type。");
        }
        if (category != null && (category < 1 || category > 5))
        {
            return ToolResult.read("分类取值 1-5。");
        }
        if (type != null && (type < 1 || type > 5))
        {
            return ToolResult.read("题型取值 1-5（1 单选、2 多选、3 判断、4 简答、5 编程）。");
        }
        int alive = 0;
        for (Long id : ids)
        {
            Integer hit = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_exam_question WHERE eqs_id = ?", Integer.class, id);
            if (hit != null && hit > 0)
            {
                alive++;
            }
        }
        if (alive == 0)
        {
            return ToolResult.read("这些题号在题库中都不存在。");
        }

        PendingAction action = new PendingAction();
        action.put("ids", new ArrayList<>(ids));
        action.put("category", category);
        action.put("type", type);
        register(ctx, QuestionBankSupport.SCOPE, "classify", "待确认：调整分类/题型", action);

        String target = (category == null ? "" : "分类→" + category + " ")
                + (type == null ? "" : "题型→" + QuestionBankSupport.TYPE_NAMES.getOrDefault(type, String.valueOf(type)));
        String text = "将对 " + alive + " 题执行「" + target.trim() + "」（待确认）。"
                + "其中 " + (ids.size() - alive) + " 个题号不存在会被跳过。pendingId=" + action.id + "；请让用户点击卡片确认。";
        action.summary = QuestionBankSupport.summarize(text);
        return ToolResult.propose(text, action);
    }

    @Override
    public boolean supports(PendingAction action)
    {
        return "classify".equals(action.kind) && QuestionBankSupport.SCOPE.equals(action.scope);
    }

    @Override
    public Map<String, Object> apply(PendingAction action, ToolContext ctx)
    {
        List<Long> ids = action.get("ids");
        Integer category = action.get("category");
        Integer type = action.get("type");
        int updated = 0;
        for (Long qid : ids)
        {
            StringBuilder sql = new StringBuilder("UPDATE t_exam_question SET ");
            List<Object> params = new ArrayList<>();
            boolean first = true;
            if (category != null)
            {
                sql.append("eqs_category = ?");
                params.add(category);
                first = false;
            }
            if (type != null)
            {
                if (!first)
                {
                    sql.append(", ");
                }
                sql.append("eqs_type = ?, eqs_type_name = ?");
                params.add(type);
                params.add(QuestionBankSupport.TYPE_NAMES.getOrDefault(type, "单选"));
            }
            sql.append(" WHERE eqs_id = ?");
            params.add(qid);
            updated += jdbc.update(sql.toString(), params.toArray());
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("kind", "classify");
        result.put("updated", updated);
        result.put("ids", ids);
        result.put("category", category);
        result.put("type", type);
        return result;
    }
}
