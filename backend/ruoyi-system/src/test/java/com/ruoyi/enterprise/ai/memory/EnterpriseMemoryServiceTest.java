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
import static org.mockito.Mockito.*;

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
        db.execute("create table t_enterprise_ai_memory_fact(id varchar(36) primary key,company_id bigint,user_id bigint,memory_type varchar(40),content varchar(500),evidence varchar(500),source_session_id bigint,source_message_id bigint,status varchar(16),index_status varchar(16),created_at timestamp,updated_at timestamp)");
        db.execute("create table t_enterprise_ai_memory_outbox(id bigint auto_increment primary key,company_id bigint,user_id bigint,memory_id varchar(36),operation varchar(16),status varchar(16),attempts int,next_retry_at timestamp,last_error varchar(200),created_at timestamp,updated_at timestamp)");
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

    @Test void preferencesAreSerializableInPromptPayload()
    {
        db.update("insert into t_enterprise_ai_memory values(81,7,'jd_style','简洁JD',current_timestamp)");
        var context=service.prepare(81L,7L,9L,"怎么写JD");
        assertTrue(context.data().contains("简洁JD"));
        assertTrue(context.data().contains("confirmedPreferences"));
    }

    @Test void blankQueryFallsBackToSerializableRecentFacts()
    {
        db.update("insert into t_enterprise_ai_memory_fact values(?,81,7,'other','最近事实',null,9,1,'ACTIVE','INDEXED',current_timestamp,current_timestamp)",UUID.randomUUID().toString());
        var context=service.prepare(81L,7L,9L,"");
        assertTrue(context.data().contains("最近事实"));
        assertFalse(context.data().contains("updatedAt"));
    }

    @Test void semanticRecallReranksOnlyOwnedActiveFacts() throws Exception
    {
        String first=UUID.randomUUID().toString(), second=UUID.randomUUID().toString();
        db.update("insert into t_enterprise_ai_memory_fact values(?,81,7,'interview_style','技术面只做一轮','技术面只做一轮',9,1,'ACTIVE','INDEXED',current_timestamp,current_timestamp)",first);
        db.update("insert into t_enterprise_ai_memory_fact values(?,81,7,'salary_policy','薪资按岗位预算上限执行','薪资按岗位预算上限执行',9,2,'ACTIVE','INDEXED',current_timestamp,current_timestamp)",second);
        db.update("insert into t_enterprise_ai_memory_fact values(?,82,7,'salary_policy','其他企业预算','其他企业预算',9,3,'ACTIVE','INDEXED',current_timestamp,current_timestamp)",UUID.randomUUID().toString());
        var vectors=mock(EnterpriseMemoryVectorIndex.class);
        when(vectors.configured()).thenReturn(true);
        when(vectors.embedQuery("薪资怎么定")).thenReturn(List.of(0.1,0.2));
        when(vectors.search(eq(81L),eq(7L),anyList(),eq(30))).thenReturn(List.of(
            new EnterpriseMemoryVectorIndex.Hit(first,0.72),
            new EnterpriseMemoryVectorIndex.Hit(second,0.81)));
        var reranker=mock(EnterpriseMemoryReranker.class);
        when(reranker.enabled()).thenReturn(true);
        when(reranker.rank(eq("薪资怎么定"),anyList())).thenReturn(List.of(
            new EnterpriseMemoryReranker.Rank(1,0.95),
            new EnterpriseMemoryReranker.Rank(0,0.20)));
        var properties=new EnterpriseMemoryProperties();
        properties.setRerankTopN(1);
        service=new EnterpriseMemoryService(db,mock(EnterpriseAssistantMapper.class),mock(EnterpriseAgentModelClient.class),
                vectors,reranker,properties,tx);
        var context=service.prepare(81L,7L,9L,"薪资怎么定");
        assertTrue(context.data().contains("薪资按岗位预算上限执行"));
        assertFalse(context.data().contains("技术面只做一轮"));
        assertFalse(context.data().contains("其他企业预算"));
    }

    @Test void rerankerFailureKeepsQdrantOrder() throws Exception
    {
        String first=UUID.randomUUID().toString(), second=UUID.randomUUID().toString();
        db.update("insert into t_enterprise_ai_memory_fact values(?,81,7,'interview_style','技术面只做一轮','技术面只做一轮',9,1,'ACTIVE','INDEXED',current_timestamp,current_timestamp)",first);
        db.update("insert into t_enterprise_ai_memory_fact values(?,81,7,'salary_policy','薪资按预算执行','薪资按预算执行',9,2,'ACTIVE','INDEXED',current_timestamp,current_timestamp)",second);
        var vectors=mock(EnterpriseMemoryVectorIndex.class);
        when(vectors.configured()).thenReturn(true);
        when(vectors.embedQuery("面试怎么安排")).thenReturn(List.of(0.1,0.2));
        when(vectors.search(eq(81L),eq(7L),anyList(),eq(30))).thenReturn(List.of(
            new EnterpriseMemoryVectorIndex.Hit(first,0.72),
            new EnterpriseMemoryVectorIndex.Hit(second,0.55)));
        var reranker=mock(EnterpriseMemoryReranker.class);
        when(reranker.enabled()).thenReturn(true);
        when(reranker.rank(eq("面试怎么安排"),anyList())).thenThrow(new IllegalStateException("RERANK_DOWN"));
        var properties=new EnterpriseMemoryProperties();
        properties.setRerankTopN(1);
        service=new EnterpriseMemoryService(db,mock(EnterpriseAssistantMapper.class),mock(EnterpriseAgentModelClient.class),
                vectors,reranker,properties,tx);
        var context=service.prepare(81L,7L,9L,"面试怎么安排");
        assertTrue(context.data().contains("技术面只做一轮"));
        assertFalse(context.data().contains("薪资按预算执行"));
    }

    @Test void deleteAndUpdateFactKeepTheSameId() throws Exception
    {
        String id=UUID.randomUUID().toString();
        db.update("insert into t_enterprise_ai_memory_fact values(?,81,7,'process_preference','面试流程先笔试','面试流程先笔试',9,1,'ACTIVE','INDEXED',current_timestamp,current_timestamp)",id);
        var vectors=mock(EnterpriseMemoryVectorIndex.class);
        when(vectors.configured()).thenReturn(true);
        when(vectors.embedPassages(anyList())).thenReturn(List.of(java.util.Collections.nCopies(512,0.1)));
        var properties=new EnterpriseMemoryProperties();
        service=new EnterpriseMemoryService(db,mock(EnterpriseAssistantMapper.class),mock(EnterpriseAgentModelClient.class),
                vectors,mock(EnterpriseMemoryReranker.class),properties,tx);
        service.deleteFact(81L,7L,id);
        assertEquals("DELETED",db.queryForObject("select status from t_enterprise_ai_memory_fact where id=?",String.class,id));
        verify(vectors).deleteFact(81L,7L,id);
        service.updateFact(81L,7L,id,"process_preference","面试流程改为先技术面","面试流程改为先技术面");
        assertEquals("ACTIVE",db.queryForObject("select status from t_enterprise_ai_memory_fact where id=?",String.class,id));
        assertEquals("面试流程改为先技术面",db.queryForObject("select content from t_enterprise_ai_memory_fact where id=?",String.class,id));
        verify(vectors).upsert(eq(81L),argThat(point->point.id().equals(id)&&point.memoryType().equals("process_preference")));
    }

    @Test void clearFactsMarksActiveRowsDeletedAndRemovesVectors() throws Exception
    {
        String id=UUID.randomUUID().toString();
        db.update("insert into t_enterprise_ai_memory_fact values(?,81,7,'other','待清空事实','待清空事实',9,1,'ACTIVE','INDEXED',current_timestamp,current_timestamp)",id);
        var vectors=mock(EnterpriseMemoryVectorIndex.class);
        when(vectors.configured()).thenReturn(true);
        service=new EnterpriseMemoryService(db,mock(EnterpriseAssistantMapper.class),mock(EnterpriseAgentModelClient.class),
                vectors,mock(EnterpriseMemoryReranker.class),new EnterpriseMemoryProperties(),tx);
        var result=service.clearFacts(81L,7L);
        assertEquals("DELETED",db.queryForObject("select status from t_enterprise_ai_memory_fact where id=?",String.class,id));
        verify(vectors).deleteAll(81L,7L);
        assertEquals(0,((Number)((Map<?,?>)result.get("index")).get("active")).intValue());
    }

    @Test void completedAnswerExtractsMultipleEvidenceBackedFacts() throws Exception
    {
        var chats=mock(EnterpriseAssistantMapper.class);
        when(chats.messages(anyLong(),isNull(),anyInt())).thenReturn(List.<Map<String,Object>>of(
            Map.of("id",2L,"role","user","content","我们面试只做一轮技术面"),
            Map.of("id",1L,"role","assistant","content","好的","state","C")));
        var model=mock(EnterpriseAgentModelClient.class);
        var json=new ObjectMapper();
        var reply=new EnterpriseAgentModelClient.Reply(json.createObjectNode().put("content",
            "{\"items\":[{\"memoryType\":\"interview_style\",\"content\":\"面试只做一轮技术面\",\"evidence\":\"我们面试只做一轮技术面\"},"
            + "{\"memoryType\":\"other\",\"content\":\"本轮招聘优先看算法能力\",\"evidence\":\"我们面试只做一轮技术面\"}]}"),0);
        when(model.complete(any(),any(),any(),any(),anyLong(),anyInt())).thenReturn(reply);
        service=new EnterpriseMemoryService(db,chats,model,true,tx);
        service.enqueueCompleted(81L,7L,9L,new ModelProvider());
        int count=0;
        for(int i=0;i<50&&count<2;i++)
        {
            Thread.sleep(100);
            count=db.queryForObject("select count(*) from t_enterprise_ai_memory_fact where company_id=81 and user_id=7 and status='ACTIVE'",Integer.class);
        }
        assertEquals(2,count);
        service.close();
    }
}
