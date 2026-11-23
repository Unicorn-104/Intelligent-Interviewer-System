package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.ai.agent.mapper.EnterpriseAssistantMapper;
import com.ruoyi.enterprise.ai.knowledge.EnterpriseKnowledgeService;
import com.ruoyi.system.mapper.DashboardMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Catalog and executor for the enterprise assistant's read-only tools. */
@Component
public class EnterpriseAssistantToolPackage
{
    private final ObjectMapper json = new ObjectMapper();
    private final Map<String, EnterpriseAssistantTool> tools;

    public EnterpriseAssistantToolPackage(EnterpriseAssistantMapper mapper)
    {
        this(mapper, null, null);
    }

    @Autowired
    public EnterpriseAssistantToolPackage(EnterpriseAssistantMapper mapper, DashboardMapper dashboard,
            EnterpriseKnowledgeService knowledge)
    {
        List<EnterpriseAssistantTool> definitions = new java.util.ArrayList<>(List.of(
                new ListCompanyJobsTool(mapper), new GetCompanyJobTool(mapper),
                new ListCompanyCandidatesTool(mapper), new ListUpcomingInterviewsTool(mapper)));
        if (dashboard != null)
        {
            definitions.add(new GetRecruitingDashboardTool(dashboard));
            definitions.add(new GetRecruitingFunnelTool(dashboard));
        }
        if (knowledge != null) definitions.add(new SearchCompanyKnowledgeTool(knowledge));
        Map<String, EnterpriseAssistantTool> byName = new LinkedHashMap<>();
        for (EnterpriseAssistantTool tool : definitions)
        {
            byName.put(tool.name(), tool);
        }
        tools = Map.copyOf(byName);
    }

    public ArrayNode definitions()
    {
        ArrayNode result = json.createArrayNode();
        for (EnterpriseAssistantTool tool : tools.values())
        {
            result.add(tool.definition(json));
        }
        return result;
    }

    public Object execute(String name, long companyId, JsonNode arguments)
    {
        EnterpriseAssistantTool tool = tools.get(name);
        if (tool == null)
        {
            return Map.of("error", "不支持的只读工具");
        }
        return tool.execute(companyId, arguments);
    }
}
