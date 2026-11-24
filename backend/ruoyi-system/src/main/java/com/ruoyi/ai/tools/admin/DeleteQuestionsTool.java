package com.ruoyi.ai.tools.admin;

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

/**
 * 管理端按题号删除题目：execute 只核验并登记草稿，apply 才真正删除。
 *
 * <p>被考卷（t_exam_paper_question）或答卷（t_exam_answer）引用的题一律保留，
 * 因为这两张表对 t_exam_question 是级联删除，直接删会连带清掉组卷与作答记录。</p>
 */
@Component
public class DeleteQuestionsTool extends AbstractAgentTool implements PendingActionHandler
{
    private static final int MAX_DELETE_IDS = 20;

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "delete_questions";
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
        ObjectNode ids = props.putObject("ids");
        ids.put("type", "array").put("description", "要删除的题号数组，最多 20 个").put("maxItems", MAX_DELETE_IDS);
        ids.putObject("items").put("type", "integer");
        params.putArray("required").add("ids");
        return toolDef("按题号删除题目（生成待确认草稿，不直接删除）。"
                + "用户给出题号时直接调用，无需先搜索；被考卷或答卷引用的题会自动保留；默认仅平台题库。",
                params);
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
        Set<Long> requested = readIds(args);
        if (requested.isEmpty())
        {
            return ToolResult.read("没有可删除的题目：ids 为空。");
        }
        if (requested.size() > MAX_DELETE_IDS)
        {
            return ToolResult.read("一次最多删除 " + MAX_DELETE_IDS + " 题，请分批提交。");
        }

        Set<Long> existing = existingIds(requested, bankType, companyId);
        if (existing.isEmpty())
        {
            return ToolResult.read("这些题号在指定题库中都不存在，未生成草稿。");
        }
        Set<Long> referenced = referencedIds(existing);
        Set<Long> deletable = new LinkedHashSet<>(existing);
        deletable.removeAll(referenced);
        if (deletable.isEmpty())
        {
            return ToolResult.read("这些题都被考卷或答卷引用，删除会破坏已有组卷与作答记录，已拒绝生成草稿。");
        }

        int missing = requested.size() - existing.size();
        PendingAction action = new PendingAction();
        action.put("requested", new ArrayList<>(existing));
        action.put("ids", new ArrayList<>(deletable));
        action.put("bankType", bankType);
        action.put("companyId", companyId);
        register(ctx, QuestionBankSupport.SCOPE, "delete", "待确认：删除题目", action);

        StringBuilder text = new StringBuilder("已生成删除草稿（待确认，尚未删除）：")
                .append(deletable.size()).append(" 题 ").append(joinIds(deletable)).append("。\n");
        if (!referenced.isEmpty())
        {
            text.append("被考卷或答卷引用、将保留 ").append(referenced.size())
                    .append(" 题：").append(joinIds(referenced)).append("。\n");
        }
        if (missing > 0)
        {
            text.append("不存在的题号 ").append(missing).append(" 个将被跳过。\n");
        }
        text.append("删除不可恢复。pendingId=").append(action.id).append("；请让用户点击卡片确认。");
        action.summary = QuestionBankSupport.summarize(text.toString());
        return ToolResult.propose(text.toString(), action);
    }

    /** 兼容 ids 数组、逗号分隔字符串，以及模型沿用 items[{id}] 的写法。 */
    private Set<Long> readIds(JsonNode args)
    {
        Set<Long> ids = new LinkedHashSet<>();
        JsonNode node = args.path("ids");
        if (node.isTextual())
        {
            collectText(ids, node.asText(""));
        }
        else if (node.isArray())
        {
            for (JsonNode item : node)
            {
                long id = item.isTextual() ? parseId(item.asText("")) : item.asLong(0);
                if (id > 0)
                {
                    ids.add(id);
                }
            }
        }
        if (ids.isEmpty())
        {
            JsonNode items = args.path("items");
            if (items.isArray())
            {
                for (JsonNode item : items)
                {
                    long id = item.path("id").asLong(0);
                    if (id > 0)
                    {
                        ids.add(id);
                    }
                }
            }
        }
        return ids;
    }

    private void collectText(Set<Long> ids, String raw)
    {
        for (String part : raw.split("[,，\\s]+"))
        {
            long id = parseId(part);
            if (id > 0)
            {
                ids.add(id);
            }
        }
    }

    private long parseId(String raw)
    {
        String text = raw == null ? "" : raw.trim();
        if (text.isEmpty())
        {
            return 0L;
        }
        try
        {
            return Long.parseLong(text);
        }
        catch (NumberFormatException e)
        {
            return 0L;
        }
    }

    private Set<Long> existingIds(Set<Long> ids, String bankType, Long companyId)
    {
        List<Object> params = new ArrayList<>(ids);
        String sql = "SELECT eqs_id FROM t_exam_question WHERE eqs_id IN ("
                + placeholders(ids.size()) + ")" + scopeSql(bankType, companyId, params);
        return new LinkedHashSet<>(jdbc.queryForList(sql, Long.class, params.toArray()));
    }

    /** 被组卷或作答引用的题号；这些题删除会触发级联，必须保留。 */
    private Set<Long> referencedIds(Set<Long> ids)
    {
        Set<Long> locked = new LinkedHashSet<>();
        if (ids.isEmpty())
        {
            return locked;
        }
        String in = " IN (" + placeholders(ids.size()) + ")";
        locked.addAll(jdbc.queryForList(
                "SELECT DISTINCT epq_question_id FROM t_exam_paper_question WHERE epq_question_id" + in,
                Long.class, ids.toArray()));
        locked.addAll(jdbc.queryForList(
                "SELECT DISTINCT ean_question_id FROM t_exam_answer WHERE ean_question_id" + in,
                Long.class, ids.toArray()));
        return locked;
    }

    private String placeholders(int count)
    {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < count; i++)
        {
            if (i > 0)
            {
                sb.append(',');
            }
            sb.append('?');
        }
        return sb.toString();
    }

    private String joinIds(Set<Long> ids)
    {
        StringBuilder sb = new StringBuilder();
        for (Long id : ids)
        {
            if (sb.length() > 0)
            {
                sb.append('、');
            }
            sb.append('#').append(id);
        }
        return sb.toString();
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
        return "delete".equals(action.kind) && QuestionBankSupport.SCOPE.equals(action.scope);
    }

    @Override
    public Map<String, Object> apply(PendingAction action, ToolContext ctx)
    {
        List<Number> rawRequested = action.get("requested");
        String bankType = action.get("bankType");
        Long companyId = action.get("companyId");
        Set<Long> requested = new LinkedHashSet<>();
        for (Number raw : rawRequested)
        {
            requested.add(raw.longValue());
        }

        // 草稿生成到确认之间数据可能变化：确认时按原目标题集重新核验存在性与引用。
        Set<Long> existing = existingIds(requested, bankType, companyId);
        Set<Long> referenced = referencedIds(existing);
        Set<Long> deletable = new LinkedHashSet<>(existing);
        deletable.removeAll(referenced);

        int deleted = 0;
        List<Long> deletedIds = new ArrayList<>();
        for (Long id : deletable)
        {
            List<Object> params = new ArrayList<>();
            params.add(id);
            String sql = "DELETE FROM t_exam_question WHERE eqs_id = ?" + scopeSql(bankType, companyId, params);
            int changed = jdbc.update(sql, params.toArray());
            if (changed > 0)
            {
                deleted += changed;
                deletedIds.add(id);
            }
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("kind", "delete");
        result.put("deleted", deleted);
        result.put("skipped", requested.size() - deleted);
        result.put("referenced", referenced.size());
        result.put("missing", requested.size() - existing.size());
        result.put("ids", deletedIds);
        result.put("bankType", bankType);
        result.put("companyId", companyId);
        return result;
    }
}
