package com.ruoyi.web.controller.app;

import java.util.Map;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.app.knowledge.KnowledgeService;
import com.ruoyi.system.service.app.knowledge.KnowledgeFileStore;
import com.ruoyi.system.service.app.knowledge.KnowledgeDocumentParser;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/app/ai/knowledge")
public class AppKnowledgeController extends BaseController
{
    private final KnowledgeService service;
    public AppKnowledgeController(KnowledgeService service) { this.service=service; }
    @GetMapping("/bases")
    public AjaxResult bases() { return success(Map.of("items",service.bases(getUserId()))); }
    @GetMapping("/documents")
    public AjaxResult personalDocuments() { return success(Map.of("items",service.personalDocuments(getUserId()))); }
    @PostMapping("/documents")
    public AjaxResult uploadPersonal(@RequestParam("file") MultipartFile file) throws Exception
    {
        if(file.isEmpty()||file.getSize()>KnowledgeDocumentParser.MAX_BYTES) return AjaxResult.error(400,"文件需为 1 字节至 20 MB");
        return success(service.uploadPersonal(getUserId(),file.getOriginalFilename(),file.getBytes()));
    }
    @GetMapping("/bases/{id}/documents")
    public AjaxResult documents(@PathVariable String id) { return success(Map.of("items",service.documents(getUserId(),id))); }
    @PostMapping("/bases/{id}/documents")
    public AjaxResult upload(@PathVariable String id,@RequestParam("file") MultipartFile file) throws Exception
    {
        if(file.isEmpty()||file.getSize()>KnowledgeDocumentParser.MAX_BYTES) return AjaxResult.error(400,"文件需为 1 字节至 20 MB");
        return success(service.upload(getUserId(),id,file.getOriginalFilename(),file.getBytes()));
    }
    @PostMapping("/documents/{id}/retry")
    public AjaxResult retry(@PathVariable String id) { service.retry(getUserId(),id); return success(); }
    @DeleteMapping("/documents/{id}")
    public AjaxResult delete(@PathVariable String id) { service.deleteDocument(getUserId(),id); return success(); }
    @GetMapping("/documents/{id}/original")
    public ResponseEntity<ByteArrayResource> original(@PathVariable String id) throws Exception
    {
        long user=getUserId();
        byte[] bytes=service.original(user,id);
        var doc=service.requireDocument(user,id,false);
        return ResponseEntity.ok().header(HttpHeaders.CACHE_CONTROL,"private, no-store")
                .header("X-Content-Type-Options","nosniff")
                .header(HttpHeaders.CONTENT_DISPOSITION,ContentDisposition.attachment().filename(doc.get("name").toString(),java.nio.charset.StandardCharsets.UTF_8).build().toString())
                .contentType(MediaType.parseMediaType(KnowledgeFileStore.contentType(doc.get("extension").toString())))
                .contentLength(bytes.length).body(new ByteArrayResource(bytes));
    }
}
