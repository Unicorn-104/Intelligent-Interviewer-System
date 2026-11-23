package com.ruoyi.enterprise.ai.knowledge;

import static org.junit.jupiter.api.Assertions.*;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

/** Synthetic H2 coverage for company filtering, chunking and citation numbering. */
class EnterpriseKnowledgeServiceTest
{
    private JdbcTemplate db;
    private EnterpriseKnowledgeService service;

    @BeforeEach void setup()
    {
        var ds=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1","sa","");
        db=new JdbcTemplate(ds);
        db.execute("create table t_enterprise_ai_knowledge_document(id varchar(36) primary key,company_id bigint,name varchar(80),content_length int,chunk_count int,status varchar(16),created_at timestamp,updated_at timestamp)");
        db.execute("create table t_enterprise_ai_knowledge_chunk(id varchar(36) primary key,document_id varchar(36),company_id bigint,ordinal_no int,content text)");
        service=new EnterpriseKnowledgeService(db,true);
    }

    @Test void searchIsCompanyScopedAndReturnsCitations()
    {
        service.create(81L,"招聘规范","招聘流程先筛选，再安排面试；面试必须记录评价。");
        service.create(82L,"隔离资料","招聘流程只属于另一家企业。");
        List<java.util.Map<String,Object>> hits=service.search(81L,"招聘流程",System.nanoTime()+1_000_000_000L);
        assertEquals(1,hits.size());
        assertEquals("K1",hits.get(0).get("citation"));
        assertTrue(hits.get(0).get("content").toString().contains("面试"));
    }

    @Test void deleteRemovesDocumentFromRetrieval()
    {
        var created=service.create(81L,"制度","候选人进入面试前需要确认时间。");
        assertFalse(service.search(81L,"面试",System.nanoTime()+1_000_000_000L).isEmpty());
        service.delete(81L,created.get("id").toString());
        assertTrue(service.search(81L,"面试",System.nanoTime()+1_000_000_000L).isEmpty());
    }
}
