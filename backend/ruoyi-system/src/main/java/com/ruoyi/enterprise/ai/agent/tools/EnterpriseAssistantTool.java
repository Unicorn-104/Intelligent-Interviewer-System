package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/** A read-only tool exposed to the enterprise recruitment assistant. */
public interface EnterpriseAssistantTool
{
    String name();

    ObjectNode definition(ObjectMapper json);

    Object execute(long companyId, JsonNode arguments);
}
