package com.ruoyi.enterprise.ai.agent.tools;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.ai.knowledge.EnterpriseKnowledgeService;
import java.util.Map;

/** Company-scoped retrieval tool. The service applies the owner filter before ranking. */
final class SearchCompanyKnowledgeTool implements EnterpriseAssistantTool
{
    private final EnterpriseKnowledgeService knowledge;
    SearchCompanyKnowledgeTool(EnterpriseKnowledgeService knowledge) { this.knowledge=knowledge; }
    @Override public String name() { return "search_company_knowledge"; }
    @Override public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode function=json.createObjectNode().put("name",name())
            .put("description","在当前企业已启用的招聘制度、JD规范和面试资料中检索依据；回答应引用返回的[K1]等编号");
        ObjectNode p=function.putObject("parameters").put("type","object");
        p.putObject("properties").putObject("query").put("type","string").put("maxLength",300);
        p.putArray("required").add("query");
        ObjectNode tool=json.createObjectNode().put("type","function"); tool.set("function",function); return tool;
    }
    @Override public Object execute(long companyId, JsonNode arguments)
    {
        String query=arguments==null?null:arguments.path("query").asText(null);
        if(query==null||query.isBlank()||query.length()>300) throw new ServiceException("检索问题无效",400);
        return Map.of("items",knowledge.search(companyId,query,java.lang.System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(8)),"limit",8);
    }
}
