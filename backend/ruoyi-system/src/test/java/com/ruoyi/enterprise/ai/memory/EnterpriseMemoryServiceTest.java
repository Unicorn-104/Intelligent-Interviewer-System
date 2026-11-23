package com.ruoyi.enterprise.ai.memory;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.*;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.ai.agent.client.EnterpriseAgentModelClient;
import com.ruoyi.enterprise.ai.agent.mapper.EnterpriseAssistantMapper;
import com.ruoyi.system.domain.ModelProvider;

/** Synthetic coverage for user isolation, revision fencing, secret rejection and context reset. */
class EnterpriseMemoryServiceTest
{
    private EnterpriseMemoryService service;
    private JdbcTemplate db;
    private DataSourceTransactionManager tx;
    @BeforeEach void setup()
    {
        var ds=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1","sa","");
        db=new JdbcTemplate(ds);
        db.execute("create table t_enterprise_ai_memory_state(company_id bigint,user_id bigint,enabled int,revision bigint,updated_at timestamp,primary key(company_id,user_id))");
        db.execute("create table t_enterprise_ai_memory(company_id bigint,user_id bigint,memory_key varchar(40),memory_value varchar(500),updated_at timestamp,primary key(company_id,user_id,memory_key))");
        db.execute("create table t_enterprise_ai_summary(session_id bigint primary key,company_id bigint,content varchar(3000),through_message_id bigint,revision bigint,updated_at timestamp)");
        db.execute("create table t_enterprise_ai_context_reset(session_id bigint primary key,company_id bigint,forget_before_id bigint,updated_at timestamp)");
        db.execute("create table t_ai_chat_message(acm_id bigint primary key,acm_session_id bigint)");
        db.update("insert into t_enterprise_ai_memory_state values(81,7,1,0,current_timestamp)");
        db.update("insert into t_enterprise_ai_memory_state values(81,8,1,0,current_timestamp)");
        tx=new DataSourceTransactionManager(ds);
        service=new EnterpriseMemoryService(db,mock(EnterpriseAssistantMapper.class),mock(EnterpriseAgentModelClient.class),true,tx);
    }
    @Test void saveAndRevisionFence()
    {
        assertEquals(1,db.queryForObject("select count(*) from t_enterprise_ai_memory_state where company_id=81 and user_id=7",Integer.class));
        assertEquals(0L,((Number)service.read(81L,7L).get("revision")).longValue());
        var saved=service.change(81L,7L,"save","jd_style","Use concise job descriptions",null,0L,null);
        assertEquals(1L,((Number)saved.get("revision")).longValue());
        assertEquals(1,((java.util.List<?>)saved.get("items")).size());
        assertThrows(ServiceException.class,()->service.change(81L,7L,"clear",null,null,null,0L,null));
    }
    @Test void secretsAreRejected()
    { service.read(81L,7L); assertThrows(ServiceException.class,()->service.change(81L,7L,"save","other","api_key=hidden",null,0L,null)); }
    @Test void usersStayIsolatedInsideTheCompany()
    {
        service.change(81L,7L,"save","interview_style","One technical round",null,0L,null);
        service.change(81L,8L,"save","interview_style","Two rounds with a case",null,0L,null);
        var mine=(java.util.List<?>)service.read(81L,7L).get("items");
        var other=(java.util.List<?>)service.read(81L,8L).get("items");
        assertEquals(1,mine.size()); assertEquals(1,other.size());
        assertNotEquals(((java.util.Map<?,?>)mine.get(0)).get("value"),((java.util.Map<?,?>)other.get(0)).get("value"));
    }
    @Test void resetContextFencesHistoryAndDropsOnlyThatSummary()
    {
        db.update("insert into t_ai_chat_message values(1,9),(2,9),(3,10)");
        db.update("insert into t_enterprise_ai_summary values(9,81,'old summary',2,0,current_timestamp)");
        db.update("insert into t_enterprise_ai_summary values(10,81,'other summary',3,0,current_timestamp)");
        service.change(81L,7L,"reset_context",null,null,null,0L,9L);
        assertEquals(0L,((Number)service.read(81L,7L).get("revision")).longValue());
        EnterpriseMemoryService.Context reset=service.prepare(81L,7L,9L);
        assertEquals(2L,reset.historyAfterId());
        assertFalse(reset.data().contains("old summary"));
        assertTrue(service.prepare(81L,7L,10L).data().contains("other summary"));
        service.change(81L,7L,"settings",null,null,false,0L,null);
        EnterpriseMemoryService.Context disabled=service.prepare(81L,7L,9L);
        assertTrue(disabled.data().isEmpty());
        assertEquals(2L,disabled.historyAfterId());
    }
    @Test void completedAnswerStoresModelGeneratedSummary() throws Exception
    {
        var chats=mock(EnterpriseAssistantMapper.class);
        when(chats.messages(anyLong(),isNull(),anyInt())).thenReturn(List.<Map<String,Object>>of(
            Map.of("id",2L,"role","user","content","我们面试只做一轮技术面"),
            Map.of("id",1L,"role","assistant","content","好的","state","C")));
        var model=mock(EnterpriseAgentModelClient.class);
        var reply=new EnterpriseAgentModelClient.Reply(new ObjectMapper().createObjectNode().put("content","企业偏好：一轮技术面"),0);
        when(model.complete(any(),any(),any(),any(),anyLong(),anyInt())).thenReturn(reply);
        service=new EnterpriseMemoryService(db,chats,model,true,tx);
        service.enqueueCompleted(81L,7L,9L,new ModelProvider());
        String stored=null;
        for(int i=0;i<50&&stored==null;i++)
        {
            Thread.sleep(100);
            try { stored=db.queryForObject("select content from t_enterprise_ai_summary where session_id=9",String.class); }
            catch(org.springframework.dao.EmptyResultDataAccessException ignored) { }
        }
        assertEquals("企业偏好：一轮技术面",stored);
        service.close();
    }
}
