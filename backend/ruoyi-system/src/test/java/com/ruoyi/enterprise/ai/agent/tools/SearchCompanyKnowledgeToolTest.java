package com.ruoyi.enterprise.ai.agent.tools;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Map;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.ai.knowledge.EnterpriseKnowledgeService;
import org.junit.jupiter.api.Test;

class SearchCompanyKnowledgeToolTest
{
    @Test void vectorOutageDegradesToEmptyItemsWithoutFailingTheRun() throws Exception
    {
        EnterpriseKnowledgeService knowledge=mock(EnterpriseKnowledgeService.class);
        when(knowledge.search(anyLong(),eq("试用期员工能否独立终面"),anyLong()))
                .thenThrow(new ServiceException("企业知识库向量检索不可用，请稍后重试",503));
        var tool=new SearchCompanyKnowledgeTool(knowledge);
        var result=(Map<?,?>)tool.execute(81L,new ObjectMapper().readTree("{\"query\":\"试用期员工能否独立终面\"}"));
        assertEquals(true,result.get("unavailable"));
        assertTrue(((List<?>)result.get("items")).isEmpty());
    }
}
