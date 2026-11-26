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
 * 消息模板查询（只读）：按标题、编码、渠道、状态、归属企业检索 t_msg_template。
 */
@Component
public class ListMessageTemplatesTool extends AbstractAgentTool
{
    private static final int MAX_LIMIT = 30;

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "list_message_templates";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        props.putObject("keyword").put("type", "string").put("description", "模板标题或编码关键词");
        props.putObject("channel").put("type", "string").put("description", "渠道，如站内信、邮件、短信");
        props.putObject("status").put("type", "integer").put("description", "状态：1 启用，0 停用");
        props.putObject("companyName").put("type", "string").put("description", "归属企业名称关键词");
        props.putObject("limit").put("type", "integer").put("description", "返回条数，默认 10，最多 30");
        return toolDef("查询消息模板列表（只读）。用户想了解站内信、邮件、短信模板配置时调用；不修改模板。",
                params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String keyword = ToolArgs.text(args, "keyword", 50);
        String channel = ToolArgs.text(args, "channel", 30);
        Integer status = ToolArgs.integer(args, "status");
        String companyName = ToolArgs.text(args, "companyName", 50);
        int limit = Math.min(Math.max(ToolArgs.intValue(args, "limit", 10), 1), MAX_LIMIT);

        StringBuilder sql = new StringBuilder(
                "select t.tpl_id as id, t.tpl_code as code, t.tpl_title as title, "
                        + "coalesce(t.tpl_channel,'') as channel, t.tpl_status as status, "
                        + "coalesce(t.tpl_variables,'') as variables, "
                        + "coalesce(c.cmp_name,'平台全局') as company "
                        + "from t_msg_template t left join t_cmp c on c.cmp_id = t.tpl_company_id where 1=1 ");
        List<Object> params = new ArrayList<>();
        if (!keyword.isEmpty())
        {
            sql.append("and (t.tpl_title like ? or t.tpl_code like ?) ");
            params.add("%" + keyword + "%");
            params.add("%" + keyword + "%");
        }
        if (!channel.isEmpty())
        {
            sql.append("and t.tpl_channel = ? ");
            params.add(channel);
        }
        if (status != null)
        {
            sql.append("and t.tpl_status = ? ");
            params.add(status);
        }
        if (!companyName.isEmpty())
        {
            sql.append("and c.cmp_name like ? ");
            params.add("%" + companyName + "%");
        }
        sql.append("order by t.tpl_id desc limit ?");
        params.add(limit);

        try
        {
            List<Map<String, Object>> rows = jdbc.queryForList(sql.toString(), params.toArray());
            if (rows.isEmpty())
            {
                return ToolResult.read("没有匹配的消息模板。");
            }
            StringBuilder text = new StringBuilder("匹配到 ").append(rows.size())
                    .append(" 个消息模板（最多 ").append(limit).append(" 个）：\n");
            for (Map<String, Object> row : rows)
            {
                text.append("- #").append(row.get("id")).append(' ').append(row.get("title"))
                        .append("（").append(row.get("code")).append("）")
                        .append("｜").append(row.get("company"))
                        .append("｜渠道 ").append(row.get("channel"))
                        .append("｜").append(statusLabel(row.get("status")));
                String variables = String.valueOf(row.get("variables"));
                if (!variables.isEmpty() && !"null".equals(variables))
                {
                    text.append("｜变量 ").append(variables);
                }
                text.append('\n');
            }
            return ToolResult.read(text.toString());
        }
        catch (Exception e)
        {
            return ToolResult.read("消息模板查询失败：" + e.getMessage());
        }
    }

    private String statusLabel(Object value)
    {
        int status = value == null ? 0 : ((Number) value).intValue();
        return status == 1 ? "启用" : "停用";
    }
}
