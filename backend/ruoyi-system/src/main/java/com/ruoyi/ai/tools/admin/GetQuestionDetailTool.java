package com.ruoyi.ai.tools.admin;

import java.util.ArrayList;
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
import com.ruoyi.ai.core.ToolArgs;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

/**
 * 按题号查看题目完整内容：只读。
 *
 * <p>search_questions 只回题干摘要，模型据此答不出答案、解析和分值，所以单独提供详情。</p>
 */
@Component
public class GetQuestionDetailTool extends AbstractAgentTool
{
    private static final int MAX_IDS = 5;
    private static final int MAX_CONTENT = 1000;
    private static final int MAX_ANSWER = 400;
    private static final int MAX_ANALYSIS = 600;
    private static final int MAX_OPTIONS = 1000;

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "get_question_detail";
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
        ids.put("type", "array").put("description", "题号数组，最多 5 个").put("maxItems", MAX_IDS);
        ids.putObject("items").put("type", "integer");
        params.putArray("required").add("ids");
        return toolDef("按题号查看题目完整内容：题干、选项、答案、解析、难度、分值（只读，不修改）。"
                + "用户问某题答案或解析时调用；默认仅平台题库", params);
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
        Set<Long> ids = ToolArgs.longSet(args.path("ids"));
        if (ids.isEmpty())
        {
            return ToolResult.read("请提供要查看的题号 ids。");
        }
        if (ids.size() > MAX_IDS)
        {
            return ToolResult.read("一次最多查看 " + MAX_IDS + " 题详情，请分批提交。");
        }

        List<Object> params = new ArrayList<>(ids);
        StringBuilder sql = new StringBuilder(
                "SELECT e.eqs_id AS id, e.eqs_type AS type, e.eqs_type_name AS typeName, "
                + "e.eqs_category AS category, e.eqs_content AS content, e.eqs_options_json AS optionsJson, "
                + "e.eqs_answer AS answer, e.eqs_analysis AS analysis, e.eqs_difficulty AS difficulty, "
                + "e.eqs_score AS score, e.eqs_skill_tag AS skillTag, e.eqs_company_id AS companyId "
                + "FROM t_exam_question e WHERE e.eqs_id IN ("
                + String.join(",", java.util.Collections.nCopies(ids.size(), "?")) + ")");
        sql.append(QuestionBankSupport.bankScope(bankType, "e.eqs_company_id"));
        if ("enterprise".equals(bankType))
        {
            sql.append(" AND e.eqs_company_id = ?");
            params.add(companyId);
        }
        sql.append(" ORDER BY e.eqs_id");

        List<Map<String, Object>> rows = jdbc.queryForList(sql.toString(), params.toArray());
        if (rows.isEmpty())
        {
            return ToolResult.read("指定题号在题库中都不存在。");
        }

        StringBuilder out = new StringBuilder();
        if (rows.size() < ids.size())
        {
            out.append("有 ").append(ids.size() - rows.size()).append(" 个题号不存在，已跳过。\n");
        }
        for (Map<String, Object> row : rows)
        {
            appendRow(out, row);
        }
        return ToolResult.read(out.toString().trim());
    }

    private void appendRow(StringBuilder out, Map<String, Object> row)
    {
        String typeName = row.get("typeName") == null ? ""
                : String.valueOf(row.get("typeName"));
        if (typeName.isBlank())
        {
            Object type = row.get("type");
            typeName = type instanceof Number
                    ? QuestionBankSupport.TYPE_NAMES.getOrDefault(((Number) type).intValue(), "")
                    : "";
        }
        out.append("#").append(row.get("id")).append(" [").append(typeName)
                .append(" · 分类").append(row.get("category"))
                .append(" · 难度").append(row.get("difficulty"))
                .append(" · ").append(row.get("score")).append("分]\n");
        out.append("题干：").append(ToolArgs.cut(text(row.get("content")), MAX_CONTENT)).append('\n');
        String options = describeOptions(row.get("optionsJson"));
        if (options != null)
        {
            out.append("选项：").append(options).append('\n');
        }
        out.append("答案：").append(ToolArgs.cut(text(row.get("answer")), MAX_ANSWER)).append('\n');
        String analysis = text(row.get("analysis"));
        if (!analysis.isBlank())
        {
            out.append("解析：").append(ToolArgs.cut(analysis, MAX_ANALYSIS)).append('\n');
        }
        String skillTag = text(row.get("skillTag"));
        if (!skillTag.isBlank())
        {
            out.append("技能标签：").append(ToolArgs.cut(skillTag, 100)).append('\n');
        }
        if (row.get("companyId") != null)
        {
            out.append("归属企业：").append(row.get("companyId")).append('\n');
        }
        out.append('\n');
    }

    /** 选项以 JSON 数组存放；解析失败时原样输出，不做猜测。 */
    private String describeOptions(Object raw)
    {
        String text = text(raw);
        if (text.isBlank() || "null".equalsIgnoreCase(text))
        {
            return null;
        }
        try
        {
            JsonNode node = json.readTree(text);
            if (node.isArray() && !node.isEmpty())
            {
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < node.size(); i++)
                {
                    // 每个选项独占一行，避免模型二次改写时漏项或合并
                    sb.append('\n').append("  ").append((char) ('A' + i)).append(". ")
                            .append(ToolArgs.cut(node.get(i).asText(""), 120));
                }
                return ToolArgs.cut(sb.toString(), MAX_OPTIONS);
            }
        }
        catch (Exception ignored)
        {
            // 非 JSON 的存量数据按原文展示
        }
        return ToolArgs.cut(text, MAX_OPTIONS);
    }

    private String text(Object raw)
    {
        return raw == null ? "" : String.valueOf(raw).trim();
    }
}
