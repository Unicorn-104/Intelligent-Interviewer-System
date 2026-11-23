package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.ai.agent.mapper.EnterpriseAssistantMapper;

import java.util.LinkedHashMap;
import java.util.Map;

/** Read-only search over the current enterprise's jobs. */
final class ListCompanyJobsTool implements EnterpriseAssistantTool
{
    private final EnterpriseAssistantMapper mapper;

    ListCompanyJobsTool(EnterpriseAssistantMapper mapper)
    {
        this.mapper = mapper;
    }

    @Override
    public String name()
    {
        return "list_company_jobs";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode function = json.createObjectNode();
        function.put("name", name());
        function.put("description", "只读查看当前登录招聘者企业的岗位，最多15条，不是完整统计");
        ObjectNode parameters = function.putObject("parameters");
        parameters.put("type", "object");
        parameters.putObject("properties").putObject("keyword").put("type", "string");
        ObjectNode tool = json.createObjectNode();
        tool.put("type", "function");
        tool.set("function", function);
        return tool;
    }

    @Override
    public Object execute(long companyId, JsonNode arguments)
    {
        String keyword = cleanKeyword(arguments == null ? null : arguments.path("keyword").asText(null));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("jobs", mapper.jobs(companyId, keyword));
        result.put("limit", 15);
        return result;
    }

    private String cleanKeyword(String raw)
    {
        if (raw == null)
        {
            return null;
        }
        if (raw.length() > 100 || raw.chars().anyMatch(c -> Character.isISOControl(c) && c != '\n' && c != '\t'))
        {
            throw new ServiceException("内容长度或字符不合法", 400);
        }
        return raw.isBlank() ? null : raw.trim();
    }
}
