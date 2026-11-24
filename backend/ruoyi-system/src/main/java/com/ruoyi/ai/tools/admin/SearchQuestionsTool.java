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
        props.putObject("ids").put("type", "array").put("description", "按题号精确核验，最多 20 个")
                .putObject("items").put("type", "integer");
        props.putObject("bankType").put("type", "string").put("enum",
                json.createArrayNode().add("platform").add("enterprise"));
        props.putObject("category").put("type", "integer").put("minimum", 1).put("maximum", 5);
        props.putObject("type").put("type", "integer").put("minimum", 1).put("maximum", 5)
                .put("description", "题型：1 单选 2 多选 3 判断 4 简答 5 编程");
        props.putObject("difficulty").put("type", "integer").put("minimum", 1).put("maximum", 5);
        props.putObject("limit").put("type", "integer").put("minimum", 1).put("maximum", 20);
        return toolDef("查询题库题目，返回题号、题型、分类与题干摘要；结果受 limit 限制，不能据此判断未列出题号不存在；可用 ids 精确核验", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String keyword = ToolArgs.text(args, "keyword", 100);
        String bankType = ToolArgs.text(args, "bankType", 20);
        Integer category = ToolArgs.integer(args, "category");
        Integer type = ToolArgs.integer(args, "type");
        Integer difficulty = ToolArgs.integer(args, "difficulty");
        Set<Long> ids = ToolArgs.longSet(args.path("ids"));
        if (ids.size() > 20)
        {
            return ToolResult.read("一次最多精确核验 20 个题号。");
        }
        int limit = ids.isEmpty() ? Math.min(Math.max(ToolArgs.intValue(args, "limit", 8), 1), 20) : ids.size();

        StringBuilder sql = new StringBuilder(
                "SELECT e.eqs_id AS id, e.eqs_type AS type, e.eqs_type_name AS typeName, " +
                "e.eqs_content AS content, e.eqs_category AS category, e.eqs_difficulty AS difficulty, " +
                "e.eqs_company_id AS companyId FROM t_exam_question e WHERE 1 = 1");
        List<Object> params = new ArrayList<>();
        sql.append(QuestionBankSupport.bankScope(bankType, "e.eqs_company_id"));
        if (!ids.isEmpty())
        {
            sql.append(" AND e.eqs_id IN (")
               .append(String.join(",", java.util.Collections.nCopies(ids.size(), "?")))
               .append(")");
            params.addAll(ids);
        }
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
            return ToolResult.read(ids.isEmpty() ? "题库中没有符合条件的题目。" : "指定题号在题库中都不存在。");
        }
        StringBuilder out = new StringBuilder("找到 " + rows.size() + " 题");
        if (!ids.isEmpty() && rows.size() < ids.size())
        {
            out.append("，").append(ids.size() - rows.size()).append(" 个指定题号不存在");
        }
        out.append("：\n");
        for (Map<String, Object> row : rows)
        {
            String content = ToolArgs.cut(String.valueOf(row.get("content")), 60);
            out.append("- #").append(row.get("id")).append(" [")
               .append(row.get("typeName") == null ? "" : row.get("typeName"))
               .append(" · 分类").append(row.get("category")).append("] ").append(content).append("\n");
        }
        if (ids.isEmpty())
        {
            out.append("注：以上仅为本次有限筛选结果，不能据此判断未列出的题号不存在。");
        }
        return ToolResult.read(out.toString());
    }
}
