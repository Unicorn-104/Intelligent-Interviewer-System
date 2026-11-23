package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.system.mapper.DashboardMapper;
import java.util.Map;

/** Read-only 30-day funnel for the current enterprise. */
final class GetRecruitingFunnelTool implements EnterpriseAssistantTool
{
    private final DashboardMapper dashboard;
    GetRecruitingFunnelTool(DashboardMapper dashboard) { this.dashboard=dashboard; }
    @Override public String name() { return "get_recruiting_funnel"; }
    @Override public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode function=json.createObjectNode().put("name",name())
            .put("description","读取当前企业近30天投递漏斗统计，不推断候选人质量");
        function.putObject("parameters").put("type","object").putObject("properties");
        ObjectNode tool=json.createObjectNode().put("type","function"); tool.set("function",function); return tool;
    }
    @Override public Object execute(long companyId, JsonNode ignored)
    { return dashboard==null?Map.of("error","招聘漏斗工具暂不可用"):dashboard.selectFunnel(companyId); }
}
