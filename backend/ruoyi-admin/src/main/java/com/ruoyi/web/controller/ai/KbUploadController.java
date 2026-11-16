package com.ruoyi.web.controller.ai;

import dev.langchain4j.data.document.Document;
import dev.langchain4j.data.document.DocumentSplitter;
import dev.langchain4j.data.document.splitter.DocumentByParagraphSplitter;
import dev.langchain4j.data.segment.TextSegment;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * RAG知识库管理：上传文档自动切分入库。
 * 小白版：只支持txt/md，按段落切分，每段存成一条问答对。
 */
@RestController
@RequestMapping("/ai/kb")
public class KbUploadController extends BaseController {

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private KbEmbeddingService embeddingService;

    /**
     * 上传txt/md文档，自动切分入库。
     * 用法：POST /ai/kb/upload?category=操作手册  表单传file
     */
    @PostMapping("/upload")
    public AjaxResult upload(@RequestParam("file") MultipartFile file,
                             @RequestParam(defaultValue = "未分类") String category) {
        try {
            // 1. 读文件内容
            String text;
            try (InputStream is = file.getInputStream()) {
                text = new String(is.readAllBytes(), StandardCharsets.UTF_8);
            }
            if (text.isBlank()) return error("文件内容为空");

            // 2. 用LangChain4j按段落切分：每段最多500字，最少100字
            Document doc = Document.from(text);
            DocumentSplitter splitter = new DocumentByParagraphSplitter(500, 100);
            List<TextSegment> segments = splitter.split(doc);

            // 3. 每段存到知识库表，同时存向量
            int count = 0;
            for (TextSegment seg : segments) {
                String content = seg.text().trim();
                if (content.length() < 20) continue;
                String q = content.length() > 50 ? content.substring(0, 50) + "..." : content;
                jdbc.update(
                        "INSERT INTO t_ai_knowledge (question, answer, category) VALUES (?, ?, ?)",
                        q, content, category);
                // 拿到刚插入的kb_id，存向量
                Long kbId = jdbc.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
                embeddingService.saveVector(kbId, content);
                count++;
            }

            // 4. 记录文档
            jdbc.update("INSERT INTO t_ai_kb_doc (doc_name, doc_path, doc_chunks) VALUES (?, ?, ?)",
                    file.getOriginalFilename(), "uploaded", count);

            return success("成功导入" + count + "段知识");
        } catch (Exception e) {
            logger.error("kb upload error", e);
            return error("导入失败：" + e.getMessage());
        }
    }

    /** 看知识库列表 */
    @GetMapping("/list")
    public AjaxResult list() {
        List<java.util.Map<String,Object>> rows = jdbc.queryForList(
                "SELECT kb_id, question, answer, category, use_count, created_at FROM t_ai_knowledge ORDER BY kb_id DESC LIMIT 200");
        return success(rows);
    }

    /** 新增知识 */
    @PostMapping("/add")
    public AjaxResult add(@RequestParam String question,
                          @RequestParam String answer,
                          @RequestParam(defaultValue = "手动添加") String category) {
        jdbc.update("INSERT INTO t_ai_knowledge (question, answer, category) VALUES (?,?,?)",
                question, answer, category);
        Long kbId = jdbc.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        embeddingService.saveVector(kbId, question + " " + answer);
        return success("添加成功");
    }

    /** 删除知识 */
    @DeleteMapping("/{id}")
    public AjaxResult delete(@PathVariable Long id) {
        jdbc.update("DELETE FROM t_ai_knowledge WHERE kb_id=?", id);
        jdbc.update("DELETE FROM t_ai_kb_vector WHERE kb_id=?", id);
        return success("删除成功");
    }

    /** 文档列表 */
    @GetMapping("/docs")
    public AjaxResult docs() {
        List<java.util.Map<String,Object>> rows = jdbc.queryForList(
                "SELECT * FROM t_ai_kb_doc ORDER BY doc_id DESC");
        return success(rows);
    }
}
