package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.system.mapper.DashboardMapper;
import java.util.LinkedHashMap;
import java.util.Map;

/** Read-only recruiting counters scoped to the current enterprise. */
final class GetRecruitingDashboardTool implements EnterpriseAssistantTool
{
    private final DashboardMapper dashboard;
    GetRecruitingDashboardTool(DashboardMapper dashboard) { this.dashboard = dashboard; }
    @Override public String name() { return "get_recruiting_dashboard"; }
    @Override public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode function=json.createObjectNode().put("name",name())
            .put("description","读取当前企业招聘看板的岗位、候选人、面试和笔试计数，只返回统计数据");
        function.putObject("parameters").put("type","object").putObject("properties");
        ObjectNode tool=json.createObjectNode().put("type","function"); tool.set("function",function); return tool;
    }
    @Override public Object execute(long companyId, JsonNode ignored)
    {
        if (dashboard == null) return Map.of("error","招聘看板工具暂不可用");
        Map<String,Object> result=new LinkedHashMap<>();
        result.put("activePositions",dashboard.countActivePositions(companyId));
        result.put("candidateResumes",dashboard.countResumes(companyId));
        result.put("pendingInterviews",dashboard.countPendingInterviews(companyId));
        result.put("weeklyCompletedInterviews",dashboard.countWeeklyCompletedInterviews(companyId));
        result.put("pendingExams",dashboard.countPendingExams(companyId));
        return result;
    }
}
