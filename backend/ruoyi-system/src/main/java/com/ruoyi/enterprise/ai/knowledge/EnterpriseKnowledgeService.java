package com.ruoyi.enterprise.ai.knowledge;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;

/**
 * Company-scoped RAG corpus. MySQL is the source of truth; retrieval uses a bounded
 * lexical rank so the feature remains useful when the optional embedding service is off.
 */
@Service
public class EnterpriseKnowledgeService
{
    private final JdbcTemplate db;
    private final boolean enabled;

    public EnterpriseKnowledgeService(JdbcTemplate db,
            @Value("${app.ai.enterprise.rag.enabled:false}") boolean enabled)
    { this.db = db; this.enabled = enabled; }

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
        requireEnabled(); requireCompany(companyId);
        String cleanName=clean(name,80,"knowledge document name is invalid");
        String cleanContent=clean(content,200_000,"knowledge content is invalid");
        if (cleanContent.isBlank()) throw new ServiceException("knowledge content cannot be empty",400);
        String document=UUID.randomUUID().toString();
        List<String> chunks=split(cleanContent,1200);
        db.update("insert into t_enterprise_ai_knowledge_document(id,company_id,name,content_length,chunk_count,status,created_at,updated_at) values(?,?,?,?,?,'ACTIVE',?,?)",
                document,companyId,cleanName,cleanContent.length(),chunks.size(),java.sql.Timestamp.from(Instant.now()),java.sql.Timestamp.from(Instant.now()));
        for(int i=0;i<chunks.size();i++) db.update("insert into t_enterprise_ai_knowledge_chunk(id,document_id,company_id,ordinal_no,content) values(?,?,?,?,?)",
                UUID.randomUUID().toString(),document,companyId,i,chunks.get(i));
        return Map.of("id",document,"name",cleanName,"chunkCount",chunks.size());
    }

    public void delete(long companyId,String document)
    {
        requireEnabled(); requireCompany(companyId);
        if(document==null||!document.matches("[0-9a-fA-F-]{36}")) throw new ServiceException("document id is invalid",400);
        int changed=db.update("update t_enterprise_ai_knowledge_document set status='DELETED',updated_at=? where id=? and company_id=? and status='ACTIVE'",
                java.sql.Timestamp.from(Instant.now()),document,companyId);
        if(changed==0) throw new ServiceException("document not found or not accessible",404);
    }

    public List<Map<String,Object>> search(long companyId,String query,long deadlineNanos)
    {
        requireCompany(companyId); if (!enabled) return List.of();
        String normalized=clean(query,300,"knowledge query is invalid"); if(normalized.isBlank()) return List.of();
        if(System.nanoTime()>deadlineNanos) throw new ServiceException("knowledge search timeout",503);
        List<Map<String,Object>> rows;
        try { rows=db.queryForList("select c.id as chunkId,d.id as documentId,d.name as fileName,c.content "
                    + "from t_enterprise_ai_knowledge_chunk c join t_enterprise_ai_knowledge_document d on d.id=c.document_id "
                    + "where c.company_id=? and d.company_id=? and d.status='ACTIVE'",companyId,companyId); }
        catch(DataAccessException error) { return List.of(); }
        String[] terms=normalized.toLowerCase().split("\\s+");
        List<Map<String,Object>> ranked=new ArrayList<>();
        for(Map<String,Object> row:rows) {
            String content=String.valueOf(row.get("content")); String lower=content.toLowerCase(); int score=0;
            for(String term:terms) if(!term.isBlank()&&lower.contains(term)) score+=Math.max(1,term.length());
            if(score>0) { Map<String,Object> copy=new LinkedHashMap<>(row); copy.put("score",score); ranked.add(copy); }
        }
        ranked.sort(Comparator.comparingInt(r->-((Number)r.get("score")).intValue()));
        List<Map<String,Object>> result=new ArrayList<>(); int citation=1;
        for(Map<String,Object> row:ranked.stream().limit(8).toList()) {
            row.remove("score"); row.put("citation","K"+citation++);
            String content=String.valueOf(row.get("content")); row.put("content",content.length()>1600?content.substring(0,1600):content);
            result.add(row);
        }
        return result;
    }

    private void requireEnabled() { if(!enabled) throw new ServiceException("enterprise knowledge is disabled",503); }
    private static void requireCompany(long companyId) { if(companyId<=0) throw new ServiceException("company id is invalid",400); }
    private static String clean(String value,int max,String message)
    { if(value==null||value.length()>max||value.chars().anyMatch(c->Character.isISOControl(c)&&c!='\n'&&c!='\t')) throw new ServiceException(message,400); return value.trim(); }
    private static List<String> split(String text,int size)
    { List<String> out=new ArrayList<>(); for(int i=0;i<text.length();i+=size) out.add(text.substring(i,Math.min(text.length(),i+size))); return out; }
}

