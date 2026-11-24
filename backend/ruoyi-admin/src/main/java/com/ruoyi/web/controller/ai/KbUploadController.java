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
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.apache.poi.xwpf.usermodel.XWPFParagraph;

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

    /** 单文件上限 10MB */
    private static final long MAX_FILE_SIZE = 10L * 1024 * 1024;

    /** 可按纯文本读取的扩展名 */
    private static final Set<String> TEXT_EXT = Set.of("txt", "md", "markdown", "csv", "json", "xml",
            "yml", "yaml", "sql", "log", "java", "py", "js", "ts", "html", "css");

    /**
     * 上传txt/md文档，自动切分入库。
     * 用法：POST /ai/kb/upload?category=操作手册  表单传file
     */
    @PostMapping("/upload")
    public AjaxResult upload(@RequestParam("file") MultipartFile file,
                             @RequestParam(defaultValue = "未分类") String category) {
        try {
            int count = importFile(file, category);
            return success("成功导入" + count + "段知识");
        } catch (Exception e) {
            logger.error("kb upload error", e);
            return error("导入失败：" + e.getMessage());
        }
    }

    /**
     * 批量导入：文件多选或整个文件夹一次提交。
     * 用法：POST /ai/kb/upload-batch?category=操作手册  表单 files 传多个文件
     */
    @PostMapping("/upload-batch")
    public AjaxResult uploadBatch(@RequestParam("files") MultipartFile[] files,
                                  @RequestParam(defaultValue = "未分类") String category) {
        if (files == null || files.length == 0) {
            return error("请选择要导入的文件");
        }
        if (files.length > 50) {
            return error("单次最多导入 50 个文件，请分批提交");
        }
        List<Map<String, Object>> results = new ArrayList<>();
        int success = 0;
        int failed = 0;
        int totalChunks = 0;
        for (MultipartFile file : files) {
            Map<String, Object> item = new LinkedHashMap<>();
            String name = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
            item.put("name", name);
            try {
                int chunks = importFile(file, category);
                item.put("chunks", chunks);
                success++;
                totalChunks += chunks;
            } catch (Exception e) {
                item.put("error", e.getMessage() == null ? "解析失败" : e.getMessage());
                failed++;
            }
            results.add(item);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("total", files.length);
        data.put("success", success);
        data.put("failed", failed);
        data.put("chunks", totalChunks);
        data.put("files", results);
        return success("导入完成：" + success + " 个成功，" + failed + " 个失败").put("data", data);
    }

    /**
     * 解析随对话上传的附件，只返回文本内容，不写入知识库。
     * 用法：POST /ai/kb/parse  表单 files 传多个文件
     */
    @PostMapping("/parse")
    public AjaxResult parse(@RequestParam("files") MultipartFile[] files) {
        if (files == null || files.length == 0) {
            return error("请选择文件");
        }
        if (files.length > 5) {
            return error("单次最多 5 个附件");
        }
        List<Map<String, Object>> out = new ArrayList<>();
        for (MultipartFile file : files) {
            Map<String, Object> item = new LinkedHashMap<>();
            String name = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
            item.put("name", name);
            try {
                if (file.isEmpty()) {
                    throw new IllegalArgumentException("文件内容为空");
                }
                if (file.getSize() > MAX_FILE_SIZE) {
                    throw new IllegalArgumentException("超过 10MB 限制");
                }
                String text = extractText(name, file);
                if (text == null || text.isBlank()) {
                    throw new IllegalArgumentException("未解析到文本内容");
                }
                // 单个附件最多 3000 字，避免超模型上下文
                item.put("text", text.length() > 3000 ? text.substring(0, 3000) + "\n…（已截断）" : text);
            } catch (Exception e) {
                item.put("error", e.getMessage() == null ? "解析失败" : e.getMessage());
            }
            out.add(item);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("files", out);
        return success(data);
    }

    /** 解析单个文件并入库，返回写入的知识段数。 */
    private int importFile(MultipartFile file, String category) throws Exception {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("文件内容为空");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("超过 10MB 限制");
        }
        String name = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
        String text = extractText(name, file);
        if (text == null || text.isBlank()) {
            throw new IllegalArgumentException("未解析到文本内容");
        }
        return storeSegments(text, category, name);
    }

    /** 按扩展名抽取纯文本；不支持的格式明确报错，避免乱码入库。 */
    private String extractText(String name, MultipartFile file) throws Exception {
        String ext = "";
        int dot = name.lastIndexOf('.');
        if (dot >= 0 && dot < name.length() - 1) {
            ext = name.substring(dot + 1).toLowerCase(Locale.ROOT);
        }
        if (TEXT_EXT.contains(ext)) {
            try (InputStream is = file.getInputStream()) {
                String text = new String(is.readAllBytes(), StandardCharsets.UTF_8);
                // 兼容 Windows 记事本保存的 UTF-8 BOM
                return text.startsWith("\uFEFF") ? text.substring(1) : text;
            }
        }
        if ("pdf".equals(ext)) {
            try (InputStream is = file.getInputStream(); PDDocument doc = PDDocument.load(is)) {
                return new PDFTextStripper().getText(doc);
            }
        }
        if ("docx".equals(ext)) {
            try (InputStream is = file.getInputStream(); XWPFDocument doc = new XWPFDocument(is)) {
                StringBuilder sb = new StringBuilder();
                for (XWPFParagraph p : doc.getParagraphs()) {
                    sb.append(p.getText()).append('\n');
                }
                return sb.toString();
            }
        }
        if ("xlsx".equals(ext)) {
            try (InputStream is = file.getInputStream(); Workbook wb = WorkbookFactory.create(is)) {
                StringBuilder sb = new StringBuilder();
                DataFormatter fmt = new DataFormatter();
                for (Sheet sheet : wb) {
                    sb.append("【").append(sheet.getSheetName()).append("】\n");
                    for (Row row : sheet) {
                        List<String> cells = new ArrayList<>();
                        for (Cell cell : row) {
                            cells.add(fmt.formatCellValue(cell));
                        }
                        if (!String.join("", cells).isBlank()) {
                            sb.append(String.join("\t", cells)).append('\n');
                        }
                    }
                }
                return sb.toString();
            }
        }
        if ("doc".equals(ext)) {
            throw new IllegalArgumentException("暂不支持 .doc，请另存为 .docx 后重试");
        }
        throw new IllegalArgumentException("不支持的文件类型：" + (ext.isEmpty() ? "无扩展名" : ext));
    }

    /** 按段落切分入库并记录文档，返回写入段数。 */
    private int storeSegments(String text, String category, String fileName) {
        Document doc = Document.from(text);
        DocumentSplitter splitter = new DocumentByParagraphSplitter(500, 100);
        List<TextSegment> segments = splitter.split(doc);
        int count = 0;
        for (TextSegment seg : segments) {
            String content = seg.text().trim();
            if (content.length() < 20) {
                continue;
            }
            String q = content.length() > 50 ? content.substring(0, 50) + "..." : content;
            jdbc.update(
                    "INSERT INTO t_ai_knowledge (question, answer, category) VALUES (?, ?, ?)",
                    q, content, category);
            Long kbId = jdbc.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
            embeddingService.saveVector(kbId, content);
            count++;
        }
        jdbc.update("INSERT INTO t_ai_kb_doc (doc_name, doc_path, doc_chunks) VALUES (?, ?, ?)",
                fileName, "uploaded", count);
        return count;
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
