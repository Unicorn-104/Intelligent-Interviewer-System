package com.ruoyi.ai.tools.admin;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.AbstractAgentTool;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

/** 平台业务统计：岗位总数、候选人总数、近 7 天新增候选人。 */
@Component
public class GetDashboardStatsTool extends AbstractAgentTool
{
    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "get_dashboard_stats";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        params.set("properties", json.createObjectNode());
        return toolDef("查询平台真实业务统计：岗位总数、候选人总数、最近7天新增候选人", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        Integer pos = jdbc.queryForObject("SELECT COUNT(*) FROM t_pos", Integer.class);
        Integer tal = jdbc.queryForObject("SELECT COUNT(*) FROM t_tal", Integer.class);
        Integer recent = jdbc.queryForObject(
                "SELECT COUNT(*) FROM t_tal WHERE tal_created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)",
                Integer.class);
        return ToolResult.read("岗位总数=" + pos + "；候选人总数=" + tal + "；近7天新增候选人=" + recent);
    }
}
