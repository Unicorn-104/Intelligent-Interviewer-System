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
 * 人才库查询（只读）：按企业、候选人状态、归档来源检索 t_tal，返回投递数量。
 */
@Component
public class SearchTalentTool extends AbstractAgentTool
{
    private static final int MAX_LIMIT = 30;

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "search_talent";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        props.putObject("companyName").put("type", "string").put("description", "企业名称关键词");
        props.putObject("status").put("type", "integer")
                .put("description", "候选人状态：0 新入库，1 初筛通过，2 面试中，3 已淘汰，4 已录用，5 待笔试，6 笔试中，7 笔试通过，8 笔试未通过，9 笔试缺考");
        props.putObject("archiveSource").put("type", "integer")
                .put("description", "归档来源：0 未归档，1 笔试淘汰，2 面试淘汰，3 主动归档，4 初筛淘汰");
        props.putObject("limit").put("type", "integer").put("description", "返回条数，默认 10，最多 30");
        return toolDef("查询人才库候选人（只读）。用户想了解候选人数量、状态分布、某企业的候选人时调用；不返回联系方式，不修改数据。",
                params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String companyName = ToolArgs.text(args, "companyName", 50);
        Integer status = ToolArgs.integer(args, "status");
        Integer archiveSource = ToolArgs.integer(args, "archiveSource");
        int limit = Math.min(Math.max(ToolArgs.intValue(args, "limit", 10), 1), MAX_LIMIT);

        StringBuilder sql = new StringBuilder(
                "select t.tal_id as id, coalesce(c.cmp_name,'') as company, t.tal_status as status, "
                        + "t.tal_archive_source as archiveSource, "
                        + "(select count(*) from t_app_record a where a.app_candidate_id = t.tal_id) as apps "
                        + "from t_tal t left join t_cmp c on c.cmp_id = t.tal_company_id where 1=1 ");
        List<Object> params = new ArrayList<>();
        if (!companyName.isEmpty())
        {
            sql.append("and c.cmp_name like ? ");
            params.add("%" + companyName + "%");
        }
        if (status != null)
        {
            sql.append("and t.tal_status = ? ");
            params.add(status);
        }
        if (archiveSource != null)
        {
            sql.append("and t.tal_archive_source = ? ");
            params.add(archiveSource);
        }
        sql.append("order by t.tal_id desc limit ?");
        params.add(limit);

        try
        {
            List<Map<String, Object>> rows = jdbc.queryForList(sql.toString(), params.toArray());
            if (rows.isEmpty())
            {
                return ToolResult.read("没有匹配的候选人。");
            }
            StringBuilder text = new StringBuilder("匹配到 ").append(rows.size())
                    .append(" 位候选人（最多 ").append(limit).append(" 位）：\n");
            for (Map<String, Object> row : rows)
            {
                text.append("- #").append(row.get("id")).append(' ').append(row.get("company"))
                        .append("｜").append(statusLabel(row.get("status")))
                        .append("｜归档 ").append(archiveLabel(row.get("archiveSource")))
                        .append("｜投递 ").append(row.get("apps")).append(" 份\n");
            }
            return ToolResult.read(text.toString());
        }
        catch (Exception e)
        {
            return ToolResult.read("人才库查询失败：" + e.getMessage());
        }
    }

    private String statusLabel(Object value)
    {
        int status = value == null ? 0 : ((Number) value).intValue();
        String[] labels = { "新入库", "初筛通过", "面试中", "已淘汰", "已录用", "待笔试", "笔试中", "笔试通过", "笔试未通过",
                "笔试缺考" };
        return status >= 0 && status < labels.length ? labels[status] : "状态" + status;
    }

    private String archiveLabel(Object value)
    {
        int source = value == null ? 0 : ((Number) value).intValue();
        String[] labels = { "未归档", "笔试淘汰", "面试淘汰", "主动归档", "初筛淘汰" };
        return source >= 0 && source < labels.length ? labels[source] : "来源" + source;
    }
}
