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

/**
 * 岗位查询（只读）：按岗位名、企业、城市、状态检索 t_pos，最多返回 30 条。
 */
@Component
public class SearchJobsTool extends AbstractAgentTool
{
    private static final int MAX_LIMIT = 30;

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "search_jobs";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        props.putObject("keyword").put("type", "string").put("description", "岗位名称或部门关键词");
        props.putObject("companyName").put("type", "string").put("description", "企业名称关键词");
        props.putObject("city").put("type", "string").put("description", "工作城市");
        props.putObject("status").put("type", "integer").put("description", "岗位状态：1 上架，2 或 3 下架");
        props.putObject("limit").put("type", "integer").put("description", "返回条数，默认 10，最多 30");
        return toolDef("查询岗位列表（只读）。用户想了解岗位、在招岗位、某企业的岗位时调用；不修改任何数据。",
                params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String keyword = ToolArgs.text(args, "keyword", 50);
        String companyName = ToolArgs.text(args, "companyName", 50);
        String city = ToolArgs.text(args, "city", 30);
        Integer status = ToolArgs.integer(args, "status");
        int limit = Math.min(Math.max(ToolArgs.intValue(args, "limit", 10), 1), MAX_LIMIT);

        StringBuilder sql = new StringBuilder(
                "select p.pos_id as id, p.pos_title as title, coalesce(c.cmp_name,'') as company, "
                        + "coalesce(p.pos_work_city,'') as city, p.pos_salary_min as salaryMin, "
                        + "p.pos_salary_max as salaryMax, p.pos_status as status, "
                        + "date_format(p.pos_created_at,'%Y-%m-%d') as created "
                        + "from t_pos p left join t_cmp c on c.cmp_id = p.pos_company_id where 1=1 ");
        List<Object> params = new ArrayList<>();
        if (!keyword.isEmpty())
        {
            sql.append("and (p.pos_title like ? or p.pos_department like ?) ");
            params.add("%" + keyword + "%");
            params.add("%" + keyword + "%");
        }
        if (!companyName.isEmpty())
        {
            sql.append("and c.cmp_name like ? ");
            params.add("%" + companyName + "%");
        }
        if (!city.isEmpty())
        {
            sql.append("and p.pos_work_city = ? ");
            params.add(city);
        }
        if (status != null)
        {
            sql.append("and p.pos_status = ? ");
            params.add(status);
        }
        sql.append("order by p.pos_id desc limit ?");
        params.add(limit);

        try
        {
            List<Map<String, Object>> rows = jdbc.queryForList(sql.toString(), params.toArray());
            if (rows.isEmpty())
            {
                return ToolResult.read("没有匹配的岗位。");
            }
            StringBuilder text = new StringBuilder("匹配到 ").append(rows.size())
                    .append(" 条岗位（最多 ").append(limit).append(" 条）：\n");
            for (Map<String, Object> row : rows)
            {
                text.append("- #").append(row.get("id")).append(' ').append(row.get("title"))
                        .append("｜").append(row.get("company"))
                        .append("｜").append(row.get("city"))
                        .append("｜薪资 ").append(row.get("salaryMin")).append('-').append(row.get("salaryMax"))
                        .append("｜").append(statusLabel(row.get("status")))
                        .append("｜发布于 ").append(row.get("created")).append('\n');
            }
            return ToolResult.read(text.toString());
        }
        catch (Exception e)
        {
            return ToolResult.read("岗位查询失败：" + e.getMessage());
        }
    }

    private String statusLabel(Object value)
    {
        int status = value == null ? 0 : ((Number) value).intValue();
        if (status == 1)
        {
            return "上架";
        }
        return status == 2 || status == 3 ? "下架" : "状态" + status;
    }
}
