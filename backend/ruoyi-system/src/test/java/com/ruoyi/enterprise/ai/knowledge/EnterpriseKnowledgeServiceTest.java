package com.ruoyi.enterprise.ai.knowledge;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.UUID;
import com.ruoyi.common.exception.ServiceException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

/** Synthetic H2 coverage for company filtering, vector hits and citation numbering. */
class EnterpriseKnowledgeServiceTest
{
    private JdbcTemplate db;
    private EnterpriseKnowledgeVectorIndex vectors;
    private EnterpriseKnowledgeService service;

    @BeforeEach void setup() throws Exception
    {
        var ds=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1","sa","");
        db=new JdbcTemplate(ds);
        db.execute("create table t_enterprise_ai_knowledge_document(id varchar(36) primary key,company_id bigint,name varchar(80),content_length int,chunk_count int,status varchar(16),created_at timestamp,updated_at timestamp)");
        db.execute("create table t_enterprise_ai_knowledge_chunk(id varchar(36) primary key,document_id varchar(36),company_id bigint,ordinal_no int,content text)");
        vectors=mock(EnterpriseKnowledgeVectorIndex.class);
        when(vectors.configured()).thenReturn(true);
        when(vectors.embedPassages(anyList())).thenAnswer(invocation -> {
            List<String> texts=invocation.getArgument(0);
            return texts.stream().map(text -> List.of(0.1d,0.2d)).toList();
        });
        when(vectors.embedQuery(anyString())).thenReturn(List.of(0.1d,0.2d));
        service=new EnterpriseKnowledgeService(db,new DataSourceTransactionManager(ds),vectors,true);
    }

    @Test void searchUsesCompanyScopedVectorHitsAndReturnsCitations() throws Exception
    {
        var created=service.create(81L,"招聘规范","招聘流程先筛选，再安排面试；面试必须记录评价。");
        service.create(82L,"隔离资料","招聘流程只属于另一家企业。");
        String chunkId=db.queryForObject("select id from t_enterprise_ai_knowledge_chunk where company_id=81",String.class);
        when(vectors.search(eq(81L),anyList(),eq(20))).thenReturn(List.of(
                new EnterpriseKnowledgeVectorIndex.Hit(chunkId,0.91)));
        List<java.util.Map<String,Object>> hits=service.search(81L,"招聘流程",System.nanoTime()+1_000_000_000L);
        assertEquals(1,hits.size());
        assertEquals("K1",hits.get(0).get("citation"));
        assertTrue(hits.get(0).get("content").toString().contains("面试"));
        verify(vectors).upsertBatch(eq(81L),eq(created.get("id").toString()),anyList(),anyList());
        assertTrue(service.search(82L,"招聘流程",System.nanoTime()+1_000_000_000L).isEmpty());
    }

    @Test void deleteRemovesDocumentFromRetrieval() throws Exception
    {
        var created=service.create(81L,"制度","候选人进入面试前需要确认时间。");
        String chunkId=db.queryForObject("select id from t_enterprise_ai_knowledge_chunk where company_id=81",String.class);
        when(vectors.search(eq(81L),anyList(),eq(20))).thenReturn(List.of(
                new EnterpriseKnowledgeVectorIndex.Hit(chunkId,0.92)));
        assertFalse(service.search(81L,"面试",System.nanoTime()+1_000_000_000L).isEmpty());
        service.delete(81L,created.get("id").toString());
        assertTrue(service.search(81L,"面试",System.nanoTime()+1_000_000_000L).isEmpty());
        verify(vectors).deleteDocument(81L,created.get("id").toString());
    }

    @Test void reindexRebuildsActiveDocumentVectors() throws Exception
    {
        service.create(81L,"制度","候选人进入面试前需要确认时间。");
        var rebuilt=service.reindex(81L);
        assertEquals(1,rebuilt.get("documents"));
        assertEquals(1,rebuilt.get("chunks"));
        verify(vectors,times(2)).upsertBatch(eq(81L),anyString(),anyList(),anyList());
    }

    @Test void vectorServiceMustBeConfigured()
    {
        when(vectors.configured()).thenReturn(false);
        assertThrows(ServiceException.class,() -> service.create(81L,"制度","内容"));
        assertThrows(ServiceException.class,() -> service.search(81L,"内容",System.nanoTime()+1_000_000_000L));
    }
}
