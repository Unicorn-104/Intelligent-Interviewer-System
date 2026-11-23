package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.ai.agent.mapper.EnterpriseAssistantMapper;
import java.util.LinkedHashMap;
import java.util.Map;

/** Candidate list is deliberately bounded and only exposes enterprise-owned fields. */
final class ListCompanyCandidatesTool implements EnterpriseAssistantTool
{
    private final EnterpriseAssistantMapper mapper;
    ListCompanyCandidatesTool(EnterpriseAssistantMapper mapper) { this.mapper=mapper; }
    @Override public String name() { return "list_company_candidates"; }
    @Override public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode function=json.createObjectNode().put("name",name())
            .put("description","按姓名或岗位关键词查询当前企业候选人摘要，最多20条；不返回简历原文和联系方式");
        ObjectNode parameters=function.putObject("parameters").put("type","object");
        parameters.putObject("properties").putObject("keyword").put("type","string").put("maxLength",100);
        ObjectNode tool=json.createObjectNode().put("type","function"); tool.set("function",function); return tool;
    }
    @Override public Object execute(long companyId, JsonNode arguments)
    {
        String keyword=arguments==null?null:arguments.path("keyword").asText(null);
        if(keyword!=null&&(keyword.length()>100||keyword.chars().anyMatch(Character::isISOControl)))
            throw new ServiceException("关键词无效",400);
        Map<String,Object> result=new LinkedHashMap<>();
        result.put("candidates",mapper.candidates(companyId,keyword==null||keyword.isBlank()?null:keyword.trim(),20));
        result.put("limit",20); return result;
    }
}
