package com.ruoyi.ai.tools.admin;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

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

/** 查询题库题目：只读，返回题号、题型、分类与题干摘要。 */
@Component
public class SearchQuestionsTool extends AbstractAgentTool
{
    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "search_questions";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        props.putObject("keyword").put("type", "string").put("description", "题干关键词，可空");
        props.putObject("bankType").put("type", "string").put("enum",
                json.createArrayNode().add("platform").add("enterprise"));
        props.putObject("category").put("type", "integer").put("minimum", 1).put("maximum", 5);
        props.putObject("type").put("type", "integer").put("minimum", 1).put("maximum", 5)
                .put("description", "题型：1 单选 2 多选 3 判断 4 简答 5 编程");
        props.putObject("difficulty").put("type", "integer").put("minimum", 1).put("maximum", 5);
        props.putObject("limit").put("type", "integer").put("minimum", 1).put("maximum", 20);
        return toolDef("查询题库题目，返回题号、题型、分类与题干摘要", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String keyword = ToolArgs.text(args, "keyword", 100);
        String bankType = ToolArgs.text(args, "bankType", 20);
        Integer category = ToolArgs.integer(args, "category");
        Integer type = ToolArgs.integer(args, "type");
        Integer difficulty = ToolArgs.integer(args, "difficulty");
        int limit = Math.min(Math.max(ToolArgs.intValue(args, "limit", 8), 1), 20);

        StringBuilder sql = new StringBuilder(
                "SELECT e.eqs_id AS id, e.eqs_type AS type, e.eqs_type_name AS typeName, " +
                "e.eqs_content AS content, e.eqs_category AS category, e.eqs_difficulty AS difficulty, " +
                "e.eqs_company_id AS companyId FROM t_exam_question e WHERE 1 = 1");
        List<Object> params = new ArrayList<>();
        sql.append(QuestionBankSupport.bankScope(bankType, "e.eqs_company_id"));
        if (!keyword.isEmpty())
        {
            sql.append(" AND e.eqs_content LIKE ?");
            params.add("%" + keyword + "%");
        }
        if (category != null)
        {
            sql.append(" AND e.eqs_category = ?");
            params.add(category);
        }
        if (type != null)
        {
            sql.append(" AND e.eqs_type = ?");
            params.add(type);
        }
        if (difficulty != null)
        {
            sql.append(" AND e.eqs_difficulty = ?");
            params.add(difficulty);
        }
        sql.append(" ORDER BY e.eqs_id DESC LIMIT ?");
        params.add(limit);

        List<Map<String, Object>> rows = jdbc.queryForList(sql.toString(), params.toArray());
        if (rows.isEmpty())
        {
            return ToolResult.read("题库中没有符合条件的题目。");
        }
        StringBuilder out = new StringBuilder("找到 " + rows.size() + " 题：\n");
        for (Map<String, Object> row : rows)
        {
            String content = ToolArgs.cut(String.valueOf(row.get("content")), 60);
            out.append("- #").append(row.get("id")).append(" [")
               .append(row.get("typeName") == null ? "" : row.get("typeName"))
               .append(" · 分类").append(row.get("category")).append("] ").append(content).append("\n");
        }
        return ToolResult.read(out.toString());
    }
}
