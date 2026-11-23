package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.enterprise.ai.agent.mapper.EnterpriseAssistantMapper;
import java.util.Map;

/** Upcoming interviews scoped by company id in SQL. */
final class ListUpcomingInterviewsTool implements EnterpriseAssistantTool
{
    private final EnterpriseAssistantMapper mapper;
    ListUpcomingInterviewsTool(EnterpriseAssistantMapper mapper) { this.mapper=mapper; }
    @Override public String name() { return "list_upcoming_interviews"; }
    @Override public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode function=json.createObjectNode().put("name",name())
            .put("description","读取当前企业即将开始的面试安排，最多20条");
        function.putObject("parameters").put("type","object").putObject("properties");
        ObjectNode tool=json.createObjectNode().put("type","function"); tool.set("function",function); return tool;
    }
    @Override public Object execute(long companyId, JsonNode ignored)
    { return Map.of("interviews",mapper.upcomingInterviews(companyId,20),"limit",20); }
}
