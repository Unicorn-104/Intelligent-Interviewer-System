package com.ruoyi.system.service.app.knowledge;

import java.security.MessageDigest;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/** MySQL is authoritative. Revalidate vector hits against live ownership and document versions. */
@Service
public class KnowledgeService
{
    private final JdbcTemplate db;
    private final TransactionTemplate tx;
    private final KnowledgeFileStore files;
    private final KnowledgeDocumentParser parser;
    private final KnowledgeVectorIndex vectors;
    private final ObjectMapper json = new ObjectMapper();
    private boolean enabled;
    private int maxBases=20, maxDocuments=100;
    private long maxUserBytes=200L*1024*1024;
    public KnowledgeService(JdbcTemplate db, PlatformTransactionManager manager, KnowledgeFileStore files,
            KnowledgeDocumentParser parser, KnowledgeVectorIndex vectors)
    { this.db=db; tx=new TransactionTemplate(manager); this.files=files; this.parser=parser; this.vectors=vectors; }
    @Autowired
    public void configure(Environment environment) {
        enabled=environment.getProperty("app.ai.knowledge.enabled", Boolean.class, false);
        maxBases=Math.max(1,Math.min(100,environment.getProperty("app.ai.knowledge.max-bases",Integer.class,20)));
        maxDocuments=Math.max(1,Math.min(100,environment.getProperty("app.ai.knowledge.max-documents",Integer.class,100)));
        maxUserBytes=Math.max(20,environment.getProperty("app.ai.knowledge.max-user-size-mb",Long.class,200L))*1024*1024;
    }
    public void setEnabled(boolean value) { enabled=value; }
    public boolean enabled() { return enabled; }
    private void available() { if (!enabled) throw new ServiceException("知识库暂未启用",503); }
    private void identity(long user) { if (user<=0) throw new ServiceException("请先登录",401); }
    private static String id() { return UUID.randomUUID().toString(); }
    private static int number(Map<String,Object> row,String key) { return ((Number)row.get(key)).intValue(); }

    public List<Map<String,Object>> bases(long user)
    {
        available(); identity(user);
        return db.queryForList("select b.id,b.name,b.scope,(select count(*) from t_capp_knowledge_document d "
                +"where d.base_id=b.id and d.user_id=b.user_id and d.status<>'DELETED') as documentCount "
                +"from t_capp_knowledge_base b where b.user_id=? and b.status='ACTIVE' and b.scope='PERSONAL' order by b.created_at desc",user);
    }
    /** One internal personal store; UI categories are views, not user-managed knowledge bases. */
    public String personalStore(long user)
    {
        available(); identity(user);
        return tx.execute(status -> {
            db.queryForList("select user_id from sys_user where user_id=? for update",user);
            String base=UUID.nameUUIDFromBytes(("capp-personal-space:"+user).getBytes(java.nio.charset.StandardCharsets.UTF_8)).toString();
            if(db.queryForObject("select count(*) from t_capp_knowledge_base where id=? and user_id=?",Integer.class,base,user)==0)
                db.update("insert into t_capp_knowledge_base(id,user_id,name) values(?,?,?)",base,user,"个人资料");
            return base;
        });
    }
    public List<Map<String,Object>> personalDocuments(long user)
    {
        available(); identity(user);
        return db.queryForList("select d.id,d.name,d.extension,d.file_size as size,d.status,d.chunk_count as chunkCount,"
                +"d.error_code as errorCode,d.created_at as createdAt,'UPLOAD' as source,'FILE' as category "
                +"from t_capp_knowledge_document d join t_capp_knowledge_base b on b.id=d.base_id "
                +"where d.user_id=? and b.user_id=? and b.scope='PERSONAL' and b.status='ACTIVE' and d.status<>'DELETED' order by d.created_at desc",user,user);
    }
    public Map<String,Object> uploadPersonal(long user,String name,byte[] bytes)
    { return upload(user,personalStore(user),name,bytes); }
    public List<String> automaticScope(long user)
    {
        if(!enabled) return List.of(); identity(user);
        return db.queryForList("select distinct b.id from t_capp_knowledge_base b join t_capp_knowledge_document d on d.base_id=b.id "
                +"where b.user_id=? and d.user_id=? and b.scope='PERSONAL' and b.status='ACTIVE' and d.status<>'DELETED' and d.active_revision>0 order by b.id",String.class,user,user);
    }
    public Map<String,Object> createBase(long user,String name)
    {
        available(); identity(user);
        if (name==null||name.isBlank()||name.strip().length()>80) throw new ServiceException("知识库名称需为 1 至 80 字",400);
        return tx.execute(status->{
            db.queryForList("select user_id from sys_user where user_id=? for update",user);
            if (bases(user).size()>=maxBases) throw new ServiceException("知识库数量已达到上限",400);
            String base=id(), title=name.strip().replaceAll("[\\p{Cntrl}]"," ");
            db.update("insert into t_capp_knowledge_base(id,user_id,name) values(?,?,?)",base,user,title);
            return Map.of("id",base,"name",title,"scope","PERSONAL","documentCount",0);
        });
    }
    public List<String> scope(long user,List<String> ids)
    {
        if (ids==null||ids.isEmpty()) return List.of();
        available(); identity(user);
        if (ids.size()>100||ids.stream().anyMatch(v->v==null||!v.matches("[a-f0-9-]{36}"))) throw new ServiceException("资料范围无效",400);
        var selected=new ArrayList<>(new LinkedHashSet<>(ids)); selected.sort(Comparator.naturalOrder());
        selected.forEach(base->requireBase(user,base,false)); return List.copyOf(selected);
    }
    private Map<String,Object> requireBase(long user,String base,boolean lock)
    {
        var rows=db.queryForList("select * from t_capp_knowledge_base where id=? and user_id=? and scope='PERSONAL' and status='ACTIVE'"+(lock?" for update":""),base,user);
        if (rows.isEmpty()) throw new ServiceException("知识库不存在或无权访问",404); return rows.get(0);
    }
    public List<Map<String,Object>> documents(long user,String base)
    {
        available(); identity(user); requireBase(user,base,false);
        return db.queryForList("select id,base_id as baseId,name,extension,file_size as size,status,chunk_count as chunkCount,"
                +"error_code as errorCode,created_at as createdAt from t_capp_knowledge_document where user_id=? and base_id=? and status<>'DELETED' order by created_at desc limit 101",user,base);
    }
    public Map<String,Object> upload(long user,String base,String name,byte[] bytes)
    {
        available(); identity(user); requireBase(user,base,false);
        if (name==null||name.isBlank()||name.length()>180||name.contains("/")||name.contains("\\")||name.chars().anyMatch(Character::isISOControl)) throw new ServiceException("文件名称无效",400);
        int dot=name.lastIndexOf('.'); String extension=dot<0?"":name.substring(dot+1).toLowerCase(Locale.ROOT);
        if (!Set.of("pdf","docx","txt","md").contains(extension)) throw new ServiceException("支持 PDF、DOCX、TXT、Markdown 文件",400);
        if (bytes.length==0||bytes.length>KnowledgeDocumentParser.MAX_BYTES) throw new ServiceException("文件需为 1 字节至 20 MB",400);
        try
        {
            String hash=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
            return tx.execute(status->{
                db.queryForList("select user_id from sys_user where user_id=? for update",user);
                requireBase(user,base,true);
                var duplicate=db.queryForList("select id,status from t_capp_knowledge_document where user_id=? and base_id=? and file_hash=? and status<>'DELETED' limit 1",user,base,hash);
                if (!duplicate.isEmpty()) return duplicate.get(0);
                if (documents(user,base).size()>=maxDocuments) throw new ServiceException("该知识库文件数量已达到上限",400);
                Long used=db.queryForObject("select coalesce(sum(file_size),0) from t_capp_knowledge_document where user_id=? and status<>'DELETED'",Long.class,user);
                if(used!=null && used+bytes.length>maxUserBytes) throw new ServiceException("个人知识库容量已达到上限，请先删除不需要的资料",400);
                String reference; try { reference=files.store(user,extension,bytes); } catch(Exception e) { throw new ServiceException("资料保存失败，请稍后重试",503); }
                String document=id();
                try {
                    db.update("insert into t_capp_knowledge_document(id,base_id,user_id,name,extension,file_size,file_hash,storage_ref) values(?,?,?,?,?,?,?,?)",document,base,user,name,extension,bytes.length,hash,reference);
                    enqueue(document,"INDEX");
                } catch(RuntimeException e) { try { files.delete(user,reference); } catch(Exception ignored) { } throw e; }
                return Map.of("id",document,"status","QUEUED");
            });
        } catch(ServiceException e) { throw e; } catch(Exception e) { throw new ServiceException("资料上传失败，请重试",503); }
    }
    public void retry(long user,String document)
    {
        available(); identity(user);
        tx.executeWithoutResult(status->{
            var doc=requireDocument(user,document,true);
            if (!List.of("FAILED","READY").contains(doc.get("status"))) throw new ServiceException("资料正在处理中",409);
            db.update("update t_capp_knowledge_document set revision=revision+1,status='QUEUED',error_code=null,updated_at=current_timestamp(3) where id=?",document);
            enqueue(document,"INDEX");
        });
    }
    public void deleteDocument(long user,String document)
    {
        available(); identity(user);
        tx.executeWithoutResult(status->{
            requireDocument(user,document,true);
            db.update("update t_capp_knowledge_document set status='DELETED',active_revision=0,updated_at=current_timestamp(3) where id=? and user_id=?",document,user);
            enqueue(document,"DELETE");
        });
    }
    public void deleteBase(long user,String base)
    {
        available(); identity(user);
        tx.executeWithoutResult(status->{
            requireBase(user,base,true);
            for(var doc:documents(user,base)) deleteDocument(user,doc.get("id").toString());
            db.update("update t_capp_knowledge_base set status='DELETED' where id=? and user_id=?",base,user);
        });
    }
    public Map<String,Object> requireDocument(long user,String document,boolean lock)
    {
        var rows=db.queryForList("select d.* from t_capp_knowledge_document d join t_capp_knowledge_base b on b.id=d.base_id where d.id=? and d.user_id=? and b.user_id=? and b.status='ACTIVE' and d.status<>'DELETED'"+(lock?" for update":""),document,user,user);
        if(rows.isEmpty()) throw new ServiceException("资料不存在或无权访问",404); return rows.get(0);
    }
    public byte[] original(long user,String document) throws Exception
    { available(); identity(user); var doc=requireDocument(user,document,false); return files.read(user,doc.get("storage_ref").toString()); }
    private void enqueue(String document,String operation)
    {
        db.update("delete from t_capp_knowledge_job where document_id=?",document);
        db.update("insert into t_capp_knowledge_job(document_id,operation) values(?,?)",document,operation);
        if(operation.equals("DELETE")) db.update("update t_capp_knowledge_job set available_at=? where document_id=?",
                java.sql.Timestamp.from(Instant.now().plusSeconds(30)),document);
    }
    public void saveScope(long user,String session,String run,List<String> scope)
    { if(!scope.isEmpty()) db.update("insert into t_capp_knowledge_run(run_id,user_id,session_id,scope_json) values(?,?,?,?)",run,user,session,encode(scope)); }
    public List<String> runScope(long user,String run)
    {
        if(!enabled) return List.of();
        var rows=db.queryForList("select scope_json from t_capp_knowledge_run where run_id=? and user_id=?",run,user);
        if(rows.isEmpty()) return List.of();
        try { return json.readValue(rows.get(0).get("scope_json").toString(),new TypeReference<List<String>>(){}); }
        catch(Exception e) { throw new IllegalStateException("KNOWLEDGE_SCOPE"); }
    }
    public void deleteRuns(long user,List<String> sessions)
    { if(enabled) for(String session:sessions) db.update("delete from t_capp_knowledge_run where user_id=? and session_id=?",user,session); }
    public List<Map<String,Object>> search(long user,List<String> bases,String query,long deadline) throws Exception
    {
        var selected=scope(user,bases); if(selected.isEmpty()) return List.of(); checkDeadline(deadline);
        String bounded=query.codePoints().limit(120).collect(StringBuilder::new,StringBuilder::appendCodePoint,StringBuilder::append).toString();
        var hits=vectors.search(user,selected,vectors.embed(bounded,true)); checkDeadline(deadline);
        List<Map<String,Object>> result=new ArrayList<>(); Set<String> seen=new LinkedHashSet<>();
        for(var hit:hits)
        {
            var rows=chunk(user,hit.id()); if(rows.isEmpty()) continue; var row=rows.get(0);
            if(!selected.contains(row.get("baseId"))||!seen.add(row.get("content").toString())) continue;
            row.put("score",hit.score()); result.add(row); if(result.size()>=6) break;
        }
        var adjacent=new ArrayList<Map<String,Object>>();
        for(var hit:result) {
            var ids=db.queryForList("select n.id from t_capp_knowledge_chunk c join t_capp_knowledge_chunk n on n.document_id=c.document_id and n.revision=c.revision "
                    +"where c.id=? and c.user_id=? and n.user_id=? and abs(n.ordinal_no-c.ordinal_no)=1 order by n.ordinal_no",hit.get("chunkId"),user,user);
            for(var nearby:ids) {
                var found=chunk(user,nearby.get("id").toString());
                if(!found.isEmpty() && seen.add(found.get(0).get("content").toString())) adjacent.add(found.get(0));
                if(result.size()+adjacent.size()>=12) break;
            }
            if(result.size()+adjacent.size()>=12) break;
        }
        result.addAll(adjacent);
        return result;
    }
    private List<Map<String,Object>> chunk(long user,String chunk)
    {
        return db.queryForList("select c.id as chunkId,c.document_id as documentId,c.base_id as baseId,c.page_no as page,c.section_title as section,c.content,d.name as fileName,c.revision from t_capp_knowledge_chunk c "
                +"join t_capp_knowledge_document d on d.id=c.document_id join t_capp_knowledge_base b on b.id=c.base_id where c.id=? and c.user_id=? and d.user_id=? and b.user_id=? and b.status='ACTIVE' and d.status<>'DELETED' and d.active_revision=c.revision",chunk,user,user,user);
    }
    public void saveSources(long user,String run,List<Map<String,Object>> sources,String answer)
    {
        if(sources.isEmpty()) return; var refs=new ArrayList<Map<String,Object>>();
        for(var source:sources) if(answer.contains("["+source.get("citation")+"]")&&!chunk(user,source.get("chunkId").toString()).isEmpty())
            refs.add(Map.of("citation",source.get("citation"),"chunkId",source.get("chunkId")));
        db.update("update t_capp_knowledge_run set sources_json=? where run_id=? and user_id=?",encode(refs),run,user);
    }
    public List<Map<String,Object>> sources(long user,String run)
    {
        if(!enabled||run==null) return List.of();
        var rows=db.queryForList("select sources_json from t_capp_knowledge_run where run_id=? and user_id=?",run,user);
        if(rows.isEmpty()||rows.get(0).get("sources_json")==null) return List.of();
        try {
            var refs=json.readValue(rows.get(0).get("sources_json").toString(),new TypeReference<List<Map<String,Object>>>(){});
            var result=new ArrayList<Map<String,Object>>();
            for(var ref:refs) {
                var found=chunk(user,ref.get("chunkId").toString());
                Map<String,Object> source=found.isEmpty()?new LinkedHashMap<>(Map.of("unavailable",true,"fileName","来源已删除或更新")):found.get(0);
                source.put("citation",ref.get("citation")); result.add(source);
            }
            return result;
        } catch(Exception e) { throw new IllegalStateException("KNOWLEDGE_SOURCES"); }
    }
    public static String sanitizeCitations(String answer,List<Map<String,Object>> sources)
    {
        Set<String> allowed=new HashSet<>(); for(var source:sources) allowed.add(source.get("citation").toString());
        return Pattern.compile("\\[K[0-9]+\\]").matcher(answer).replaceAll(m->allowed.contains(m.group().substring(1,m.group().length()-1))?m.group():"");
    }
    public String encode(Object value) { try { return json.writeValueAsString(value); } catch(Exception e) { throw new IllegalStateException("KNOWLEDGE_JSON"); } }
    private void checkDeadline(long deadline) { if(Thread.currentThread().isInterrupted()||System.nanoTime()>deadline) throw new IllegalStateException("KNOWLEDGE_TIMEOUT"); }

    @Scheduled(fixedDelay=3000,initialDelay=10000)
    public void work()
    {
        if(!enabled) return;
        var candidates=db.queryForList("select document_id from t_capp_knowledge_job where (status='PENDING' and available_at<=current_timestamp(3)) or (status='RUNNING' and lease_until<current_timestamp(3)) limit 1");
        if(candidates.isEmpty()) return; String document=candidates.get(0).get("document_id").toString(),token=id();
        if(db.update("update t_capp_knowledge_job set status='RUNNING',lease_token=?,lease_until=?,attempts=attempts+1 where document_id=? and ((status='PENDING' and available_at<=current_timestamp(3)) or (status='RUNNING' and lease_until<current_timestamp(3)))",token,java.sql.Timestamp.from(Instant.now().plusSeconds(300)),document)!=1) return;
        var doc=db.queryForList("select * from t_capp_knowledge_document where id=?",document).get(0);
        var jobs=db.queryForList("select * from t_capp_knowledge_job where document_id=? and lease_token=?",document,token); if(jobs.isEmpty()) return;
        long user=((Number)doc.get("user_id")).longValue(); int revision=number(doc,"revision");
        try {
            if("DELETE".equals(jobs.get(0).get("operation"))) {
                vectors.deleteDocument(user,document); files.delete(user,doc.get("storage_ref").toString());
                db.update("delete from t_capp_knowledge_chunk where document_id=? and user_id=?",document,user);
            } else {
                db.update("update t_capp_knowledge_document set status='PROCESSING' where id=? and revision=? and status='QUEUED'",document,revision);
                var parts=parser.parse(files.read(user,doc.get("storage_ref").toString()),doc.get("extension").toString());
                for(int i=0;i<parts.size();i++) {
                    if(!leaseCurrent(document,token)) return; var part=parts.get(i);
                    String chunkId=UUID.nameUUIDFromBytes((document+":"+revision+":"+i).getBytes(java.nio.charset.StandardCharsets.UTF_8)).toString();
                    var vector=vectors.embed(part.text(),false);
                    int ordinal=i;
                    boolean indexed=Boolean.TRUE.equals(tx.execute(status->{
                        // Serialize the last external write with deletion/reindex of this document.
                        // A superseded worker must never recreate vectors after a successful cleanup.
                        var current=db.queryForList("select status,revision from t_capp_knowledge_document where id=? for update",document);
                        if(current.isEmpty()||"DELETED".equals(current.get(0).get("status"))
                                ||number(current.get(0),"revision")!=revision||!leaseCurrent(document,token)) return false;
                        if(db.queryForObject("select count(*) from t_capp_knowledge_chunk where id=?",Integer.class,chunkId)==0)
                            db.update("insert into t_capp_knowledge_chunk(id,document_id,base_id,user_id,revision,ordinal_no,page_no,section_title,content) values(?,?,?,?,?,?,?,?,?)",chunkId,document,doc.get("base_id"),user,revision,ordinal,part.page(),part.section(),part.text());
                        try { vectors.upsert(chunkId,user,doc.get("base_id").toString(),document,revision,vector); }
                        catch(Exception error) { throw new IllegalStateException("KNOWLEDGE_INDEX_UNAVAILABLE",error); }
                        return true;
                    }));
                    if(!indexed) return;
                    if(!leaseCurrent(document,token)) return;
                }
                tx.executeWithoutResult(status->{
                    if(leaseCurrent(document,token)) db.update("update t_capp_knowledge_document set status='READY',active_revision=?,chunk_count=?,error_code=null,updated_at=current_timestamp(3) where id=? and revision=? and status<>'DELETED'",revision,parts.size(),document,revision);
                });
            }
            db.update("update t_capp_knowledge_job set status='DONE',lease_token=null where document_id=? and lease_token=?",document,token);
        } catch(Exception error) {
            String code=error instanceof IllegalArgumentException&&error.getMessage()!=null&&Set.of("FILE_FORMAT","FILE_SIZE","PDF_LIMIT","TEXT_LIMIT","NO_TEXT_OCR_REQUIRED").contains(error.getMessage())?error.getMessage():"PROCESSING_UNAVAILABLE";
            int attempts=number(jobs.get(0),"attempts"); boolean terminal=!code.equals("PROCESSING_UNAVAILABLE")||attempts>=5;
            int changed=db.update("update t_capp_knowledge_job set status=?,available_at=?,lease_token=null,error_code=? where document_id=? and lease_token=?",terminal?"FAILED":"PENDING",java.sql.Timestamp.from(Instant.now().plusSeconds(Math.min(300,15L*attempts))),code,document,token);
            if(changed==1) db.update("update t_capp_knowledge_document set status=?,error_code=?,updated_at=current_timestamp(3) where id=? and revision=? and status<>'DELETED'",terminal?"FAILED":"QUEUED",code,document,revision);
        }
    }
    private boolean leaseCurrent(String document,String token)
    { return db.update("update t_capp_knowledge_job set lease_until=? where document_id=? and lease_token=? and status='RUNNING'",java.sql.Timestamp.from(Instant.now().plusSeconds(300)),document,token)==1; }
}
