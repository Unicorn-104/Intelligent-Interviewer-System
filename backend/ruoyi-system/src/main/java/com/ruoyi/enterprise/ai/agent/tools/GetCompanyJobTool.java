package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.ai.agent.mapper.EnterpriseAssistantMapper;

import java.util.Map;

/** Read-only lookup of one job belonging to the current enterprise. */
final class GetCompanyJobTool implements EnterpriseAssistantTool
{
    private final EnterpriseAssistantMapper mapper;

    GetCompanyJobTool(EnterpriseAssistantMapper mapper)
    {
        this.mapper = mapper;
    }

    @Override
    public String name()
    {
        return "get_company_job";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode function = json.createObjectNode();
        function.put("name", name());
        function.put("description", "只读查看本企业指定岗位的JD，不接受其他企业数据");
        ObjectNode parameters = function.putObject("parameters");
        parameters.put("type", "object");
        parameters.putObject("properties").putObject("id").put("type", "integer");
        parameters.putArray("required").add("id");
        ObjectNode tool = json.createObjectNode();
        tool.put("type", "function");
        tool.set("function", function);
        return tool;
    }

    @Override
    public Object execute(long companyId, JsonNode arguments)
    {
        long id = positiveId(arguments == null ? null : arguments.path("id").asText());
        Map<String, Object> job = mapper.job(companyId, id);
        return job == null
                ? Map.of("error", "岗位不存在或不属于当前企业")
                : job;
    }

    private long positiveId(String raw)
    {
        try
        {
            long value = Long.parseLong(raw == null ? "" : raw);
            if (value > 0)
            {
                return value;
            }
        }
        catch (RuntimeException ignored)
        {
            // Normalize malformed model arguments to the existing business error.
        }
        throw new ServiceException("标识无效", 400);
    }
}
