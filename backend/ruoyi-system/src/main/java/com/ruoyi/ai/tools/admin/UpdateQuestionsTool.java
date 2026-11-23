package com.ruoyi.ai.tools.admin;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
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

/** 管理端按题号修改题目字段：execute 只登记草稿，apply 才执行 UPDATE。 */
@Component
public class UpdateQuestionsTool extends AbstractAgentTool implements PendingActionHandler
{
    private static final int MAX_UPDATE_ITEMS = 20;
    private static final int MAX_ANALYSIS = 10000;
    private static final List<String> FIELDS = List.of("content", "answer", "analysis", "difficulty", "score");
    private static final Map<String, String> COLUMNS = Map.of(
            "content", "eqs_content", "answer", "eqs_answer", "analysis", "eqs_analysis",
            "difficulty", "eqs_difficulty", "score", "eqs_score");
    private static final Map<String, String> LABELS = Map.of(
            "content", "题干", "answer", "答案", "analysis", "解析", "difficulty", "难度", "score", "分值");

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "update_questions";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        props.putObject("bankType").put("type", "string")
                .put("description", "platform 平台题库（默认）或 enterprise 企业题库")
                .put("enum", json.createArrayNode().add("platform").add("enterprise"));
        props.putObject("companyId").put("type", "integer").put("description", "企业题库必填，平台题库忽略");
        ObjectNode items = props.putObject("items");
        items.put("type", "array").put("description", "按题号修改的条目，最多 20 条").put("maxItems", MAX_UPDATE_ITEMS);
        ObjectNode itemSchema = items.putObject("items").put("type", "object");
        ObjectNode itemProps = itemSchema.putObject("properties");
        itemProps.putObject("id").put("type", "integer").put("description", "题号，必填");
        itemProps.putObject("content").put("type", "string").put("description", "新题干，非空");
        itemProps.putObject("answer").put("type", "string").put("description", "新答案，非空");
        itemProps.putObject("analysis").put("type", "string").put("description", "新解析，可为空字符串");
        itemProps.putObject("difficulty").put("type", "integer").put("minimum", 1).put("maximum", 3);
        itemProps.putObject("score").put("type", "number").put("exclusiveMinimum", 0);
        itemSchema.putArray("required").add("id");
        params.putArray("required").add("items");
        return toolDef("按题号修改题干、答案、解析、难度或分值（生成待确认草稿，不直接保存）。"
                + "用户给出题号时直接调用，无需先搜索；不修改题型和选项；默认仅平台题库", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String bankType = ToolArgs.text(args, "bankType", 20);
        if (bankType.isEmpty())
        {
            bankType = "platform";
        }
        if (!"platform".equals(bankType) && !"enterprise".equals(bankType))
        {
            return ToolResult.read("bankType 只支持 platform 或 enterprise。");
        }
        Long companyId = QuestionBankSupport.companyIdOf(bankType, args);
        JsonNode source = itemsNode(args);
        if (!source.isArray() || source.isEmpty())
        {
            return ToolResult.read("没有可修改的题目：items 为空。");
        }
        if (source.size() > MAX_UPDATE_ITEMS)
        {
            return ToolResult.read("一次最多修改 " + MAX_UPDATE_ITEMS + " 题，请分批提交。");
        }

        List<Map<String, Object>> items = new ArrayList<>();
        Set<Long> uniqueIds = new LinkedHashSet<>();
        for (int i = 0; i < source.size(); i++)
        {
            JsonNode node = source.get(i);
            long id = node.path("id").asLong(0);
            if (id <= 0)
            {
                return ToolResult.read("第 " + (i + 1) + " 条缺少有效题号 id。");
            }
            if (!uniqueIds.add(id))
            {
                return ToolResult.read("题号 #" + id + " 重复，请合并为一条修改。");
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", id);
            String invalid = readChanges(node, item);
            if (invalid != null)
            {
                return ToolResult.read("题号 #" + id + "：" + invalid);
            }
            items.add(item);
        }

        List<Map<String, Object>> existing = new ArrayList<>();
        int missing = 0;
        for (Map<String, Object> item : items)
        {
            if (exists(((Number) item.get("id")).longValue(), bankType, companyId))
            {
                existing.add(item);
            }
            else
            {
                missing++;
            }
        }
        if (existing.isEmpty())
        {
            return ToolResult.read("这些题号在指定题库中都不存在，未生成草稿。");
        }

        PendingAction action = new PendingAction();
        action.put("items", existing);
        action.put("bankType", bankType);
        action.put("companyId", companyId);
        register(ctx, QuestionBankSupport.SCOPE, "update", "待确认：修改题目", action);
        StringBuilder text = new StringBuilder("已生成 ").append(existing.size())
                .append(" 项题目修改草稿（待确认，尚未保存）。\n");
        for (Map<String, Object> item : existing)
        {
            text.append("- #").append(item.get("id")).append("：").append(changeLabels(item)).append('\n');
        }
        text.append("不存在的题号 ").append(missing).append(" 个将被跳过。pendingId=")
                .append(action.id).append("；请让用户点击卡片确认。");
        action.summary = QuestionBankSupport.summarize(text.toString());
        return ToolResult.propose(text.toString(), action);
    }

    private String readChanges(JsonNode node, Map<String, Object> item)
    {
        for (String field : List.of("content", "answer", "analysis"))
        {
            if (!node.has(field))
            {
                continue;
            }
            String value = node.path(field).asText("").trim();
            int max = "analysis".equals(field) ? MAX_ANALYSIS : QuestionBankSupport.MAX_CONTENT;
            if (value.length() > max)
            {
                return LABELS.get(field) + "最多 " + max + " 个字符。";
            }
            if (!"analysis".equals(field) && value.isEmpty())
            {
                return LABELS.get(field) + "不能为空。";
            }
            item.put(field, value);
        }
        if (node.has("difficulty"))
        {
            Integer difficulty = ToolArgs.integer(node, "difficulty");
            if (difficulty == null || difficulty < 1 || difficulty > 3)
            {
                return "难度取值 1-3。";
            }
            item.put("difficulty", difficulty);
        }
        if (node.has("score"))
        {
            try
            {
                BigDecimal score = new BigDecimal(node.path("score").asText());
                if (score.signum() <= 0 || score.compareTo(new BigDecimal("1000000")) >= 0)
                {
                    return "分值须大于 0 且小于 1000000。";
                }
                item.put("score", score);
            }
            catch (NumberFormatException e)
            {
                return "分值格式无效。";
            }
        }
        return item.size() == 1 ? "至少提供一个要修改的字段。" : null;
    }

    private JsonNode itemsNode(JsonNode args)
    {
        JsonNode items = args.path("items");
        if (items.isTextual())
        {
            try
            {
                return json.readTree(items.asText(""));
            }
            catch (Exception ignored)
            {
                return json.createArrayNode();
            }
        }
        return items;
    }

    private String changeLabels(Map<String, Object> item)
    {
        List<String> labels = new ArrayList<>();
        for (String field : FIELDS)
        {
            if (item.containsKey(field))
            {
                labels.add(LABELS.get(field));
            }
        }
        return String.join("、", labels);
    }

    private boolean exists(long id, String bankType, Long companyId)
    {
        List<Object> params = new ArrayList<>();
        params.add(id);
        String sql = "SELECT COUNT(*) FROM t_exam_question WHERE eqs_id = ?"
                + scopeSql(bankType, companyId, params);
        Integer count = jdbc.queryForObject(sql, Integer.class, params.toArray());
        return count != null && count > 0;
    }

    private String scopeSql(String bankType, Long companyId, List<Object> params)
    {
        if ("platform".equals(bankType))
        {
            return " AND eqs_company_id IS NULL";
        }
        params.add(companyId);
        return " AND eqs_company_id = ?";
    }

    @Override
    public boolean supports(PendingAction action)
    {
        return "update".equals(action.kind) && QuestionBankSupport.SCOPE.equals(action.scope);
    }

    @Override
    public Map<String, Object> apply(PendingAction action, ToolContext ctx)
    {
        List<Map<String, Object>> items = action.get("items");
        String bankType = action.get("bankType");
        Long companyId = action.get("companyId");
        int updated = 0;
        int skipped = 0;
        List<Long> ids = new ArrayList<>();
        for (Map<String, Object> item : items)
        {
            StringBuilder sql = new StringBuilder("UPDATE t_exam_question SET ");
            List<Object> params = new ArrayList<>();
            boolean first = true;
            for (String field : FIELDS)
            {
                if (!item.containsKey(field))
                {
                    continue;
                }
                if (!first)
                {
                    sql.append(", ");
                }
                sql.append(COLUMNS.get(field)).append(" = ?");
                params.add(item.get(field));
                first = false;
            }
            long id = ((Number) item.get("id")).longValue();
            sql.append(" WHERE eqs_id = ?");
            params.add(id);
            sql.append(scopeSql(bankType, companyId, params));
            int changed = jdbc.update(sql.toString(), params.toArray());
            updated += changed;
            if (changed > 0)
            {
                ids.add(id);
            }
            else
            {
                skipped++;
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("kind", "update");
        result.put("updated", updated);
        result.put("skipped", skipped);
        result.put("ids", ids);
        result.put("bankType", bankType);
        result.put("companyId", companyId);
        return result;
    }
}
