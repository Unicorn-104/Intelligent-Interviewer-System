package com.ruoyi.ai.tools.admin;

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

/** 题库统计：总量、题型分布、分类分布、疑似重复题干。 */
@Component
public class GetQuestionStatsTool extends AbstractAgentTool
{
    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "get_question_stats";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        params.putObject("properties").putObject("bankType").put("type", "string").put("enum",
                json.createArrayNode().add("platform").add("enterprise"));
        return toolDef("题库统计：总量、题型分布、分类分布、疑似重复题干", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String bankType = ToolArgs.text(args, "bankType", 20);
        String scope = QuestionBankSupport.bankScope(bankType, "eqs_company_id");

        Integer total = jdbc.queryForObject("SELECT COUNT(*) FROM t_exam_question WHERE 1 = 1" + scope, Integer.class);
        Integer platform = jdbc.queryForObject(
                "SELECT COUNT(*) FROM t_exam_question WHERE eqs_company_id IS NULL", Integer.class);
        Integer enterprise = jdbc.queryForObject(
                "SELECT COUNT(*) FROM t_exam_question WHERE eqs_company_id IS NOT NULL", Integer.class);

        StringBuilder out = new StringBuilder();
        out.append("题库总量=").append(total)
           .append("（系统题库 ").append(platform).append("，企业题库 ").append(enterprise).append("）\n");

        List<Map<String, Object>> byType = jdbc.queryForList(
                "SELECT eqs_type AS t, COUNT(*) AS c FROM t_exam_question WHERE 1 = 1" + scope
                + " GROUP BY eqs_type ORDER BY eqs_type");
        out.append("题型分布：");
        for (Map<String, Object> row : byType)
        {
            int t = ((Number) row.get("t")).intValue();
            out.append(QuestionBankSupport.TYPE_NAMES.getOrDefault(t, "其他")).append(' ')
               .append(row.get("c")).append("；");
        }
        out.append("\n");

        List<Map<String, Object>> byCategory = jdbc.queryForList(
                "SELECT eqs_category AS c1, COUNT(*) AS c FROM t_exam_question WHERE 1 = 1" + scope
                + " GROUP BY eqs_category ORDER BY eqs_category");
        out.append("分类分布：");
        for (Map<String, Object> row : byCategory)
        {
            out.append("分类").append(row.get("c1")).append(' ').append(row.get("c")).append("；");
        }
        out.append("\n");

        List<Map<String, Object>> dups = jdbc.queryForList(
                "SELECT LEFT(eqs_content, 40) AS snippet, COUNT(*) AS c FROM t_exam_question WHERE 1 = 1" + scope
                + " GROUP BY LEFT(eqs_content, 40) HAVING COUNT(*) > 1 ORDER BY c DESC LIMIT 5");
        if (dups.isEmpty())
        {
            out.append("未发现完全重复的题干。");
        }
        else
        {
            out.append("疑似重复题干 ").append(dups.size()).append(" 组：");
            for (Map<String, Object> row : dups)
            {
                out.append('「').append(row.get("snippet")).append("…」×").append(row.get("c")).append("；");
            }
        }
        return ToolResult.read(out.toString());
    }
}
