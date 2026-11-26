package com.ruoyi.enterprise.ai.knowledge;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import com.ruoyi.common.exception.ServiceException;

/**
 * Company-scoped RAG corpus. MySQL remains authoritative for document text,
 * while Qdrant is a rebuildable vector index used for semantic retrieval.
 */
@Service
public class EnterpriseKnowledgeService
{
    private final JdbcTemplate db;
    private final TransactionTemplate tx;
    private final EnterpriseKnowledgeVectorIndex vectors;
    private final boolean enabled;

    public EnterpriseKnowledgeService(JdbcTemplate db, PlatformTransactionManager manager,
            EnterpriseKnowledgeVectorIndex vectors,
            @Value("${app.ai.enterprise.rag.enabled:false}") boolean enabled)
    { this.db = db; this.tx = new TransactionTemplate(manager); this.vectors = vectors; this.enabled = enabled; }

    public boolean enabled() { return enabled; }

    public List<Map<String,Object>> documents(long companyId)
    {
        requireCompany(companyId); if (!enabled) return List.of();
        try {
            return db.queryForList("select id,name,content_length as contentLength,chunk_count as chunkCount,"
                    + "updated_at as updatedAt from t_enterprise_ai_knowledge_document "
                    + "where company_id=? and status='ACTIVE' order by updated_at desc limit 100", companyId);
        } catch (DataAccessException error) { return List.of(); }
    }

    public Map<String,Object> create(long companyId, String name, String content)
    {
        requireEnabled(); requireCompany(companyId); requireVectors();
        String cleanName=clean(name,80,"knowledge document name is invalid");
        String cleanContent=clean(content,200_000,"knowledge content is invalid");
        if (cleanContent.isBlank()) throw new ServiceException("knowledge content cannot be empty",400);
        String document=UUID.randomUUID().toString();
        List<String> chunks=split(cleanContent,1200);
        List<String> chunkIds=new ArrayList<>(chunks.size());
        for(int i=0;i<chunks.size();i++) chunkIds.add(UUID.randomUUID().toString());
        List<List<Double>> embeddings;
        try { embeddings=vectors.embedPassages(chunks); }
        catch(Exception error) { throw new ServiceException("企业知识库向量服务暂不可用，请稍后重试",503); }
        java.sql.Timestamp now=java.sql.Timestamp.from(Instant.now());
        try {
            tx.executeWithoutResult(status -> {
                db.update("insert into t_enterprise_ai_knowledge_document(id,company_id,name,content_length,chunk_count,status,created_at,updated_at) values(?,?,?,?,?,'PENDING',?,?)",
                        document,companyId,cleanName,cleanContent.length(),chunks.size(),now,now);
                for(int i=0;i<chunks.size();i++) db.update("insert into t_enterprise_ai_knowledge_chunk(id,document_id,company_id,ordinal_no,content) values(?,?,?,?,?)",
                        chunkIds.get(i),document,companyId,i,chunks.get(i));
            });
        } catch (DataAccessException error) { throw new ServiceException("知识库文档保存失败，请稍后重试",503); }
        try {
            vectors.upsertBatch(companyId,document,chunkIds,embeddings);
            int changed=db.update("update t_enterprise_ai_knowledge_document set status='ACTIVE',updated_at=? where id=? and company_id=?",
                    java.sql.Timestamp.from(Instant.now()),document,companyId);
            if(changed==0) throw new IllegalStateException("KNOWLEDGE_DOCUMENT_NOT_ACTIVE");
        }
        catch(Exception error) {
            db.update("update t_enterprise_ai_knowledge_document set status='FAILED',updated_at=? where id=? and company_id=?",
                    java.sql.Timestamp.from(Instant.now()),document,companyId);
            throw new ServiceException("企业知识库索引失败，请稍后重试",503);
        }
        return Map.of("id",document,"name",cleanName,"chunkCount",chunks.size());
    }

    public void delete(long companyId,String document)
    {
        requireEnabled(); requireCompany(companyId);
        if(document==null||!document.matches("[0-9a-fA-F-]{36}")) throw new ServiceException("document id is invalid",400);
        int changed=db.update("update t_enterprise_ai_knowledge_document set status='DELETED',updated_at=? where id=? and company_id=? and status='ACTIVE'",
                java.sql.Timestamp.from(Instant.now()),document,companyId);
        if(changed==0) throw new ServiceException("document not found or not accessible",404);
        // MySQL status is authoritative; stale Qdrant points are never returned
        // because search revalidates each hit against an ACTIVE document.
        try { vectors.deleteDocument(companyId,document); } catch(Exception ignored) { }
    }

    public List<Map<String,Object>> search(long companyId,String query,long deadlineNanos)
    {
        requireCompany(companyId); if (!enabled) return List.of(); requireVectors();
        String normalized=clean(query,300,"knowledge query is invalid"); if(normalized.isBlank()) return List.of();
        if(System.nanoTime()>deadlineNanos) throw new ServiceException("knowledge search timeout",503);
        List<EnterpriseKnowledgeVectorIndex.Hit> hits;
        try {
            List<Double> vector=vectors.embedQuery(normalized);
            if(System.nanoTime()>deadlineNanos) throw new ServiceException("knowledge search timeout",503);
            hits=vectors.search(companyId,vector,20);
        } catch(ServiceException error) { throw error; }
        catch(Exception error) { throw new ServiceException("企业知识库向量检索不可用，请稍后重试",503); }
        List<Map<String,Object>> result=new ArrayList<>(); Set<String> seen=new LinkedHashSet<>();
        int citation=1;
        for(EnterpriseKnowledgeVectorIndex.Hit hit:hits) {
            if(System.nanoTime()>deadlineNanos) throw new ServiceException("knowledge search timeout",503);
            var rows=db.queryForList("select c.id as chunkId,d.id as documentId,d.name as fileName,c.content "
                    + "from t_enterprise_ai_knowledge_chunk c join t_enterprise_ai_knowledge_document d on d.id=c.document_id "
                    + "where c.id=? and c.company_id=? and d.company_id=? and d.status='ACTIVE'",hit.id(),companyId,companyId);
            if(rows.isEmpty()) continue;
            Map<String,Object> row=new LinkedHashMap<>(rows.get(0));
            String content=String.valueOf(row.get("content"));
            if(!seen.add(content)) continue;
            row.put("citation","K"+citation++);
            row.put("content",content.length()>1600?content.substring(0,1600):content);
            result.add(row);
            if(result.size()>=8) break;
        }
        return result;
    }

    /** Rebuild Qdrant vectors for all active documents of one enterprise. */
    public Map<String,Object> reindex(long companyId)
    {
        requireEnabled(); requireCompany(companyId); requireVectors();
        List<String> documentIds=db.queryForList("select id from t_enterprise_ai_knowledge_document "
                + "where company_id=? and status<>'DELETED' order by updated_at",String.class,companyId);
        int chunkCount=0;
        for(String document:documentIds) {
            var chunks=db.queryForList("select id,content from t_enterprise_ai_knowledge_chunk "
                    + "where document_id=? and company_id=? order by ordinal_no",document,companyId);
            if(chunks.isEmpty()) continue;
            List<String> ids=new ArrayList<>(chunks.size());
            List<String> contents=new ArrayList<>(chunks.size());
            for(Map<String,Object> chunk:chunks) {
                ids.add(String.valueOf(chunk.get("id")));
                contents.add(String.valueOf(chunk.get("content")));
            }
            try {
                vectors.upsertBatch(companyId,document,ids,vectors.embedPassages(contents));
                db.update("update t_enterprise_ai_knowledge_document set status='ACTIVE',updated_at=? where id=? and company_id=?",
                        java.sql.Timestamp.from(Instant.now()),document,companyId);
            } catch(Exception error) {
                throw new ServiceException("企业知识库索引失败，请稍后重试",503);
            }
            chunkCount+=ids.size();
        }
        return Map.of("documents",documentIds.size(),"chunks",chunkCount);
    }

    private void requireVectors()
    { if(!vectors.configured()) throw new ServiceException("企业知识库向量服务未配置",503); }
    private void requireEnabled() { if(!enabled) throw new ServiceException("enterprise knowledge is disabled",503); }
    private static void requireCompany(long companyId) { if(companyId<=0) throw new ServiceException("company id is invalid",400); }
    private static String clean(String value,int max,String message)
    { if(value==null||value.length()>max||value.chars().anyMatch(c->Character.isISOControl(c)&&c!='\n'&&c!='\t')) throw new ServiceException(message,400); return value.trim(); }
    private static List<String> split(String text,int size)
    { List<String> out=new ArrayList<>(); for(int i=0;i<text.length();i+=size) out.add(text.substring(i,Math.min(text.length(),i+size))); return out; }
}
