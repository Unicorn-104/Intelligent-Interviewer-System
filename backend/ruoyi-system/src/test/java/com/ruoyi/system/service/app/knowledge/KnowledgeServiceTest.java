package com.ruoyi.system.service.app.knowledge;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import com.ruoyi.common.exception.ServiceException;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.springframework.core.io.FileSystemResource;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class KnowledgeServiceTest
{
    private KnowledgeService service;
    private KnowledgeVectorIndex vectors;
    private JdbcTemplate db;
    private KnowledgeFileStore files;
    @BeforeEach
    void setup() throws Exception
    {
        var source=new JdbcDataSource();
        source.setURL("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=FALSE;DB_CLOSE_DELAY=-1");
        db=new JdbcTemplate(source);
        db.execute("create table sys_user(user_id bigint primary key)");
        db.update("insert into sys_user values(17),(18)");
        try(var connection=source.getConnection()) {
            var migration=new FileSystemResource("../doc/migration_capp_knowledge_20261109.sql");
            ScriptUtils.executeSqlScript(connection,migration); ScriptUtils.executeSqlScript(connection,migration);
        }
        files=mock(KnowledgeFileStore.class); vectors=mock(KnowledgeVectorIndex.class);
        when(files.store(anyLong(),anyString(),any())).thenReturn("private-reference");
        when(files.read(anyLong(),anyString())).thenReturn("Redis 项目使用 RDB 保存快照，AOF 记录写入命令。".getBytes(StandardCharsets.UTF_8));
        when(vectors.embed(anyString(),anyBoolean())).thenReturn(List.of(1d,0d));
        service=new KnowledgeService(db,new DataSourceTransactionManager(source),files,new KnowledgeDocumentParser(),vectors);
        service.setEnabled(true);
    }
    private String base() { return service.createBase(17,"项目资料").get("id").toString(); }
    private String upload(String base) { return service.upload(17,base,"notes.txt","synthetic-content".getBytes(StandardCharsets.UTF_8)).get("id").toString(); }
    private long deadline() { return System.nanoTime()+TimeUnit.SECONDS.toNanos(20); }

    @Test void scopeAndUploadAreOwnerBound() {
        String base=base();
        assertThrows(ServiceException.class,()->service.scope(18,List.of(base)));
        assertThrows(ServiceException.class,()->service.upload(18,base,"x.txt",new byte[]{1}));
        assertThrows(ServiceException.class,()->service.upload(17,base,"../x.txt",new byte[]{1}));
        assertThrows(ServiceException.class,()->service.upload(17,base,"x.exe",new byte[]{1}));
    }
    @Test void personalUploadsAutomaticallyUseOneStoreAndRetainLegacyDocuments() {
        String store=service.personalStore(17);
        assertEquals(store,service.personalStore(17));
        assertNotEquals(store,service.personalStore(18));
        String legacy=base(); upload(legacy); service.work();
        var uploaded=service.uploadPersonal(17,"automatic.txt","different synthetic content".getBytes(StandardCharsets.UTF_8));
        service.work();
        assertEquals(2,service.personalDocuments(17).size());
        assertTrue(service.personalDocuments(18).isEmpty());
        assertEquals(store,db.queryForObject("select base_id from t_capp_knowledge_document where id=?",String.class,uploaded.get("id")));
        assertTrue(service.automaticScope(17).containsAll(List.of(store,legacy)));
        assertTrue(service.automaticScope(18).isEmpty());
        service.deleteDocument(17,uploaded.get("id").toString());
        assertEquals(List.of(legacy),service.automaticScope(17));
    }
    @Test void duplicateAndRetryUseOneDurableJob() {
        String base=base(), doc=upload(base);
        assertEquals(doc,upload(base));
        assertEquals(1,db.queryForObject("select count(*) from t_capp_knowledge_job",Integer.class));
        service.work();
        assertEquals("READY",db.queryForObject("select status from t_capp_knowledge_document where id=?",String.class,doc));
        service.retry(17,doc);
        assertEquals(1,db.queryForObject("select active_revision from t_capp_knowledge_document where id=?",Integer.class,doc));
        service.work();
        assertEquals(2,db.queryForObject("select active_revision from t_capp_knowledge_document where id=?",Integer.class,doc));
    }
    @Test void staleOrForeignVectorHitsNeverBecomeSourcesAndDeletedSourcesStayPrivate() throws Exception {
        String base=base(), doc=upload(base); service.work();
        String chunk=db.queryForObject("select id from t_capp_knowledge_chunk where document_id=? limit 1",String.class,doc);
        when(vectors.search(eq(17L),anyList(),anyList())).thenReturn(List.of(new KnowledgeVectorIndex.Hit(chunk,.9)));
        var hits=service.search(17,List.of(base),"Redis 持久化",deadline());
        assertEquals(1,hits.size()); hits.get(0).put("citation","K1");
        service.saveScope(17,"session", "run",List.of(base));
        service.saveSources(17,"run",hits,"采用 RDB [K1]");
        assertEquals(1,service.sources(17,"run").size());
        assertTrue(service.sources(18,"run").isEmpty());
        service.deleteDocument(17,doc);
        assertTrue(service.search(17,List.of(base),"Redis",deadline()).isEmpty());
        assertEquals(true,service.sources(17,"run").get(0).get("unavailable"));
        assertFalse(service.sources(17,"run").get(0).containsKey("content"));
    }
    @Test void transientIndexFailureIsRetriedWithoutPublishingPartialChunks() throws Exception {
        String base=base(),doc=upload(base);
        doThrow(new IllegalStateException()).when(vectors).upsert(anyString(),anyLong(),anyString(),anyString(),anyInt(),anyList());
        service.work();
        assertEquals(0,db.queryForObject("select active_revision from t_capp_knowledge_document where id=?",Integer.class,doc));
        assertEquals("PENDING",db.queryForObject("select status from t_capp_knowledge_job where document_id=?",String.class,doc));
    }
    @Test void deletionWhileEmbeddingIsInFlightCannotRecreateVector() throws Exception {
        String base=base(),doc=upload(base);
        when(vectors.embed(anyString(),anyBoolean())).thenAnswer(invocation->{
            service.deleteDocument(17,doc);
            return List.of(1d,0d);
        });
        service.work();
        verify(vectors,never()).upsert(anyString(),anyLong(),anyString(),anyString(),anyInt(),anyList());
        assertEquals("DELETED",db.queryForObject("select status from t_capp_knowledge_document where id=?",String.class,doc));
        assertEquals("DELETE",db.queryForObject("select operation from t_capp_knowledge_job where document_id=?",String.class,doc));
    }
    @Test void parserPreservesLocationsAndRejectsBinaryAndEmptyInput() throws Exception {
        var parser=new KnowledgeDocumentParser();
        var parts=parser.parse(("# 面试笔记\n\n"+"示例内容".repeat(100)).getBytes(StandardCharsets.UTF_8),"md");
        assertTrue(parts.size()>1); assertEquals("面试笔记",parts.get(1).section());
        assertTrue(parts.stream().allMatch(p->p.text().codePointCount(0,p.text().length())<=120));
        assertThrows(Exception.class,()->parser.parse(new byte[]{(byte)0xff},"txt"));
        assertThrows(Exception.class,()->parser.parse("   ".getBytes(),"txt"));
        assertThrows(Exception.class,()->parser.parse("not-pdf".getBytes(),"pdf"));
        assertEquals("来源 [K1] ",KnowledgeService.sanitizeCitations("来源 [K1] [K999]",List.of(Map.of("citation","K1"))));
    }
    @Test void pdfAndDocxPreserveExtractedTextAndPageLocations() throws Exception {
        var parser=new KnowledgeDocumentParser();
        try(var pdf=new org.apache.pdfbox.pdmodel.PDDocument(); var bytes=new java.io.ByteArrayOutputStream()) {
            var page=new org.apache.pdfbox.pdmodel.PDPage(); pdf.addPage(page);
            try(var content=new org.apache.pdfbox.pdmodel.PDPageContentStream(pdf,page)) {
                content.beginText(); content.setFont(new org.apache.pdfbox.pdmodel.font.PDType1Font(org.apache.pdfbox.pdmodel.font.Standard14Fonts.FontName.HELVETICA),12);
                content.newLineAtOffset(30,700); content.showText("Redis cache evidence"); content.endText();
            }
            pdf.save(bytes);
            var parts=parser.parse(bytes.toByteArray(),"pdf");
            assertEquals(1,parts.get(0).page()); assertTrue(parts.get(0).text().contains("Redis"));
        }
        try(var doc=new org.apache.poi.xwpf.usermodel.XWPFDocument(); var bytes=new java.io.ByteArrayOutputStream()) {
            doc.createParagraph().createRun().setText("项目使用 MySQL 保存资料"); doc.write(bytes);
            var parts=parser.parse(bytes.toByteArray(),"docx");
            assertTrue(parts.get(0).text().contains("MySQL")); assertEquals("段落 1",parts.get(0).section());
        }
    }
}
