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
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

/** 最近的登录失败记录，用于安全诊断。 */
@Component
public class GetRecentLoginAlertsTool extends AbstractAgentTool
{
    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "get_recent_login_alerts";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        params.set("properties", json.createObjectNode());
        return toolDef("查询最近的登录失败/异常记录，用于安全诊断", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT login_name, ipaddr, msg, login_time FROM sys_logininfor " +
                "WHERE status = '1' ORDER BY login_time DESC LIMIT 5");
        if (rows.isEmpty())
        {
            return ToolResult.read("最近没有登录失败记录");
        }
        StringBuilder sb = new StringBuilder("最近登录失败记录：\n");
        for (Map<String, Object> r : rows)
        {
            sb.append("- ").append(r.get("login_time")).append(" 用户=").append(r.get("login_name"))
              .append(" IP=").append(r.get("ipaddr")).append(" 原因=").append(r.get("msg")).append("\n");
        }
        return ToolResult.read(sb.toString());
    }
}
