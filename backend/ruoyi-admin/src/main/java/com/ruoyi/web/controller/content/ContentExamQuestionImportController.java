package com.ruoyi.web.controller.content;

import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.IModelProviderService;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.apache.poi.xwpf.usermodel.XWPFParagraph;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.io.InputStream;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 题库文件导入：解析 docx/xlsx/csv/txt/md → 切题 → 规则推断 + AI 校正分类与题型。
 * 只负责“解析预览”和“批量入库”，数据仍写 t_exam_question。
 *
 * @author TQY
 */
@RestController
@RequestMapping("/content/examQuestion/import")
public class ContentExamQuestionImportController extends BaseController {

    private static final String ENC_PREFIX = "ENC:";

    /** 题号：1. / 1、 / 1) / 第1题 / Q1 / 题目1 */
    private static final Pattern QUESTION_START = Pattern.compile(
            "^\\s*(?:第\\s*(\\d+)\\s*题|Q\\s*(\\d+)\\b|题目\\s*(\\d+)\\b|(\\d+)\\s*[.、．:：)）])\\s*(.*)$",
            Pattern.CASE_INSENSITIVE);
    /** 选项：A. / A、 / A) / (A) */
    private static final Pattern OPTION_LINE = Pattern.compile("^\\s*(?:[(（]?([A-Ha-h])[)）.、．:：])\\s*(.+)$");
    private static final Pattern ANSWER_LINE = Pattern.compile("^\\s*(?:参考)?答案\\s*[：:]\\s*(.*)$");
    private static final Pattern ANALYSIS_LINE = Pattern.compile("^\\s*解析\\s*[：:]\\s*(.*)$");
    private static final Pattern SCORE_LINE = Pattern.compile("^\\s*(?:分值|分数|得分)\\s*[：:]\\s*(\\d+(?:\\.\\d+)?).*$");

    private static final String[] TECH_WORDS = {
            "java", "spring", "mysql", "sql", "redis", "http", "tcp", "vue", "react", "flutter",
            "算法", "数据结构", "复杂度", "数组", "链表", "二叉树", "并发", "线程", "jvm", "索引",
            "事务", "框架", "组件", "接口", "微服务", "docker", "kubernetes", "linux"
    };
    private static final String[] LOGIC_WORDS = {
            "图形", "数列", "逻辑推理", "言语理解", "资料分析", "数量关系", "判断推理", "找规律", "类比", "最符合"
    };
    private static final String[] PERSONALITY_WORDS = {
            "性格", "职业倾向", "你更喜欢", "压力", "情绪", "人际", "团队角色", "做事风格", "倾向"
    };
    private static final String[] BEHAVIOR_WORDS = {
            "请举例", "一次经历", "团队冲突", "如何处理", "遇到困难", "复盘", "star", "情境", "怎么解决"
    };
    private static final String[] PROGRAM_WORDS = {
            "编程", "实现", "代码", "算法设计", "设计一个", "写出", "手写", "函数"
    };

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private IModelProviderService providerService;

    /** Single source of provider selection; see com.ruoyi.system.service.app.ai.AgentModelClient#resolve. */
    @Autowired
    private com.ruoyi.system.service.app.ai.AgentModelClient agentModelClient;

    /** 题库唯一数据出口，批量入库下沉到 ruoyi-system，供后续 AI 工具层复用。 */
    @Autowired
    private com.ruoyi.system.service.exam.IExamQuestionBankService examQuestionBankService;

    /** 导入批次记录与撤销。 */
    @Autowired
    private com.ruoyi.system.service.exam.IExamImportLogService examImportLogService;

    @Value("${ai.model.crypto-key:Intelligent-Interviewer-AI@2026}")
    private String cryptoKey;

    private final ObjectMapperHolder jsonHolder = new ObjectMapperHolder();
    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(15))
            .build();

    /** 解析上传文件（可多文件，支持一次选中整个文件夹），返回题目预览，不入库。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/parse")
    public AjaxResult parse(@RequestParam("files") MultipartFile[] files) throws Exception {
        if (files == null || files.length == 0) {
            return error("请选择文件");
        }
        List<Map<String, Object>> items = new ArrayList<>();
        List<Map<String, Object>> fileLogs = new ArrayList<>();
        for (MultipartFile f : files) {
            if (f.isEmpty()) continue;
            String name = f.getOriginalFilename() == null ? "unknown" : f.getOriginalFilename();
            Map<String, Object> log = new LinkedHashMap<>();
            log.put("name", name);
            try {
                List<Map<String, Object>> rows = parseFile(name, f);
                log.put("count", rows.size());
                log.put("status", "ok");
                for (Map<String, Object> row : rows) {
                    row.put("source", name);
                }
                items.addAll(rows);
            } catch (Exception e) {
                log.put("status", "error");
                log.put("message", e.getMessage());
            }
            fileLogs.add(log);
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("items", items);
        data.put("files", fileLogs);
        data.put("total", items.size());
        return success(data);
    }

    /** AI 校正：批量识别分类/题型/难度，失败时返回空列表由前端沿用规则结果。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/classify")
    public AjaxResult classify(@RequestBody Map<String, Object> body) {
        List<Map<String, Object>> items = asList(body.get("items"));
        if (items.isEmpty()) {
            return success(Collections.emptyList());
        }
        ModelProvider provider = activeProvider();
        if (provider == null) {
            return error("AI 模型未配置，已保留规则识别结果");
        }
        String apiKey = decryptKey(provider.getMppApiKey());
        if (apiKey == null || apiKey.isBlank()) {
            return error("AI 模型密钥无效，已保留规则识别结果");
        }
        List<Map<String, Object>> result = new ArrayList<>();
        int batch = 12;
        for (int i = 0; i < items.size(); i += batch) {
            List<Map<String, Object>> slice = items.subList(i, Math.min(items.size(), i + batch));
            try {
                List<Map<String, Object>> part = classifyBatch(provider, apiKey, slice, i);
                result.addAll(part);
            } catch (Exception e) {
                logger.error("classify batch error", e);
            }
        }
        return success(result);
    }

    /** 批量入库。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/batch")
    public AjaxResult batch(@RequestBody Map<String, Object> body) {
        List<Map<String, Object>> items = asList(body.get("items"));
        if (items.isEmpty()) {
            return error("没有可导入的题目");
        }
        String bankType = str(body.get("bankType"));
        Long companyId = toLong(body.get("companyId"));
        long cid = "enterprise".equals(bankType) ? (companyId == null ? 0L : companyId) : 0L;

        List<String> errors = new ArrayList<>();
        List<Map<String, Object>> valid = new ArrayList<>();
        if ("enterprise".equals(bankType) && cid == 0L)
        {
            return error("企业题库必须指定企业");
        }
        for (Map<String, Object> item : items)
        {
            String invalid = validate(item);
            if (invalid != null)
            {
                errors.add("第 " + (valid.size() + errors.size() + 1) + " 条：" + invalid);
                continue;
            }
            valid.add(item);
        }
        Map<String, Object> data = examQuestionBankService.batchInsert(valid, cid == 0L ? null : cid);
        // 校验阶段的错误与入库阶段的错误合并返回，保持前端既有字段（failed / errors）不变
        List<?> insertErrors = (List<?>) data.get("errors");
        if (insertErrors != null && !insertErrors.isEmpty())
        {
            for (Object msg : insertErrors)
            {
                errors.add(String.valueOf(msg));
            }
        }
        int failed = errors.size();
        data.put("failed", failed);
        data.put("errors", errors);

        // 记录本次导入，供「导入记录」查看与撤销
        @SuppressWarnings("unchecked")
        List<Long> savedIds = (List<Long>) data.get("ids");
        Object insertedObj = data.get("inserted");
        int inserted = insertedObj instanceof Number ? ((Number) insertedObj).intValue() : 0;
        Long batchId = examImportLogService.record(1, str(body.get("fileName")), cid == 0L ? null : cid,
                items.size(), inserted, failed, savedIds, getUsername());
        data.put("batchId", batchId);
        return success(data);
    }

    /** 导入记录分页列表。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @GetMapping("/logs")
    public AjaxResult logs(@RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "10") int pageSize)
    {
        return success(examImportLogService.list(pageNum, pageSize));
    }

    /** 撤销某一批次导入。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/logs/{batchId}/undo")
    public AjaxResult undo(@PathVariable Long batchId)
    {
        return success(examImportLogService.undo(batchId, getUsername()));
    }

    // ================= 文件解析 =================

    private List<Map<String, Object>> parseFile(String name, MultipartFile f) throws Exception {
        String lower = name.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".docx")) {
            return parseDocx(f);
        }
        if (lower.endsWith(".xlsx") || lower.endsWith(".xls")) {
            return parseWorkbook(f);
        }
        if (lower.endsWith(".pdf")) {
            return parsePdf(f);
        }
        if (lower.endsWith(".txt") || lower.endsWith(".md") || lower.endsWith(".csv")) {
            return parsePlainText(new String(f.getBytes(), StandardCharsets.UTF_8));
        }
        throw new IllegalArgumentException("不支持的文件类型：" + name);
    }

    /** PDF：抽取纯文本后按行切题（不支持扫描件，扫描版需 OCR）。 */
    private List<Map<String, Object>> parsePdf(MultipartFile f) throws Exception {
        StringBuilder sb = new StringBuilder();
        try (InputStream in = f.getInputStream(); PDDocument doc = PDDocument.load(in)) {
            PDFTextStripper stripper = new PDFTextStripper();
            stripper.setSortByPosition(true);
            sb.append(stripper.getText(doc));
        }
        List<String> lines = new ArrayList<>();
        String text = sb.toString().replace("\r\n", "\n").replace('\r', '\n');
        for (String ln : text.split("\n")) {
            if (ln != null && !ln.trim().isEmpty()) {
                lines.add(ln.trim());
            }
        }
        return splitQuestions(lines);
    }

    private List<Map<String, Object>> parseDocx(MultipartFile f) throws Exception {
        List<String> lines = new ArrayList<>();
        try (InputStream in = f.getInputStream(); XWPFDocument doc = new XWPFDocument(in)) {
            for (XWPFParagraph p : doc.getParagraphs()) {
                String t = p.getText();
                if (t != null) {
                    lines.add(t);
                }
            }
        }
        return splitQuestions(lines);
    }

    /** Excel：优先按表头映射（题干/选项A-.../答案/解析/分值/难度/分类/题型），否则按文本切题。 */
    private List<Map<String, Object>> parseWorkbook(MultipartFile f) throws Exception {
        List<Map<String, Object>> items = new ArrayList<>();
        try (InputStream in = f.getInputStream(); Workbook wb = WorkbookFactory.create(in)) {
            for (int si = 0; si < wb.getNumberOfSheets(); si++) {
                Sheet sheet = wb.getSheetAt(si);
                Row header = sheet.getRow(sheet.getFirstRowNum());
                if (header == null) continue;
                Map<String, Integer> col = new HashMap<>();
                for (Cell c : header) {
                    col.put(cellText(c), c.getColumnIndex());
                }
                int contentCol = findCol(col, "题干", "题目", "问题", "题目内容", "question");
                if (contentCol >= 0) {
                    for (int r = sheet.getFirstRowNum() + 1; r <= sheet.getLastRowNum(); r++) {
                        Row row = sheet.getRow(r);
                        if (row == null) continue;
                        String content = cellText(row.getCell(contentCol));
                        if (content.isBlank()) continue;
                        Map<String, Object> q = new LinkedHashMap<>();
                        q.put("content", content.trim());
                        List<String> options = new ArrayList<>();
                        for (String letter : new String[]{"A", "B", "C", "D", "E", "F"}) {
                            int idx = findCol(col, "选项" + letter, "options" + letter, letter);
                            if (idx >= 0) {
                                String v = cellText(row.getCell(idx));
                                if (!v.isBlank()) options.add(v.trim());
                            }
                        }
                        if (!options.isEmpty()) q.put("options", options);
                        int ansCol = findCol(col, "答案", "正确答案", "answer");
                        if (ansCol >= 0) q.put("answer", cellText(row.getCell(ansCol)).trim());
                        int anaCol = findCol(col, "解析", "解析说明", "analysis");
                        if (anaCol >= 0) q.put("analysis", cellText(row.getCell(anaCol)).trim());
                        int scoreCol = findCol(col, "分值", "分数", "score");
                        if (scoreCol >= 0) q.put("score", toScore(cellText(row.getCell(scoreCol))));
                        int diffCol = findCol(col, "难度", "difficulty");
                        if (diffCol >= 0) q.put("difficulty", toDifficulty(cellText(row.getCell(diffCol))));
                        int catCol = findCol(col, "分类", "题目分类", "category");
                        int typeCol = findCol(col, "题型", "类型", "type");
                        if (typeCol >= 0) q.put("type", parseTypeText(cellText(row.getCell(typeCol))));
                        if (catCol >= 0) q.put("category", parseCategoryText(cellText(row.getCell(catCol))));
                        fillDefaults(q);
                        items.add(q);
                    }
                } else {
                    List<String> lines = new ArrayList<>();
                    for (int r = sheet.getFirstRowNum(); r <= sheet.getLastRowNum(); r++) {
                        Row row = sheet.getRow(r);
                        if (row == null) continue;
                        StringBuilder sb = new StringBuilder();
                        for (Cell c : row) {
                            String v = cellText(c);
                            if (!v.isBlank()) {
                                sb.append(sb.length() > 0 ? "\t" : "").append(v);
                            }
                        }
                        if (sb.length() > 0) lines.add(sb.toString());
                    }
                    items.addAll(splitQuestions(lines));
                }
            }
        }
        return items;
    }

    private List<Map<String, Object>> parsePlainText(String text) {
        String normalized = text.replace("\r\n", "\n").replace('\r', '\n');
        List<String> lines = Arrays.asList(normalized.split("\n"));
        return splitQuestions(lines);
    }

    /** 核心：把行文本切成题目块，并抽取题干/选项/答案/解析/分值。 */
    private List<Map<String, Object>> splitQuestions(List<String> lines) {
        List<Map<String, Object>> items = new ArrayList<>();
        Map<String, Object> current = null;
        List<String> contentParts = null;
        List<String> options = null;

        for (String raw : lines) {
            String line = raw == null ? "" : raw.trim();
            if (line.isEmpty()) continue;
            Matcher start = QUESTION_START.matcher(line);
            boolean isStart = start.matches() && !isOptionLike(line);
            if (isStart) {
                if (current != null) {
                    finishQuestion(current, contentParts, options, items);
                }
                current = new LinkedHashMap<>();
                contentParts = new ArrayList<>();
                options = new ArrayList<>();
                String rest = start.group(5);
                if (rest != null && !rest.isBlank()) {
                    contentParts.add(rest.trim());
                }
                continue;
            }
            if (current == null) {
                current = new LinkedHashMap<>();
                contentParts = new ArrayList<>();
                options = new ArrayList<>();
            }
            Matcher ans = ANSWER_LINE.matcher(line);
            if (ans.matches()) {
                current.put("answer", ans.group(1).trim());
                continue;
            }
            Matcher ana = ANALYSIS_LINE.matcher(line);
            if (ana.matches()) {
                current.put("analysis", ana.group(1).trim());
                continue;
            }
            Matcher score = SCORE_LINE.matcher(line);
            if (score.matches()) {
                current.put("score", toScore(score.group(1)));
                continue;
            }
            Matcher opt = OPTION_LINE.matcher(line);
            if (opt.matches() && options.size() < 8) {
                String letter = opt.group(1).toUpperCase(Locale.ROOT);
                String text = opt.group(2).trim();
                options.add(text);
                continue;
            }
            contentParts.add(line);
        }
        if (current != null) {
            finishQuestion(current, contentParts, options, items);
        }
        return items;
    }

    private void finishQuestion(Map<String, Object> q, List<String> contentParts, List<String> options,
                                List<Map<String, Object>> items) {
        String content = String.join("\n", contentParts).trim();
        if (content.isEmpty() && options.isEmpty()) return;
        q.put("content", content);
        if (!options.isEmpty()) {
            q.put("options", new ArrayList<>(options));
        }
        fillDefaults(q);
        items.add(q);
    }

    /** 规则推断题型/分类/难度/分值，作为 AI 校正的基线。 */
    private void fillDefaults(Map<String, Object> q) {
        List<String> options = asStringList(q.get("options"));
        String content = str(q.get("content"));
        String answer = str(q.get("answer"));

        Integer type = toInt(q.get("type"));
        if (type == null) {
            if (!options.isEmpty()) {
                type = answer != null && answer.replaceAll("[^A-Za-z]", "").length() > 1 ? 2 : 1;
            } else if (answer != null && isJudgeAnswer(answer)) {
                type = 3;
            } else if (containsAny(content, PROGRAM_WORDS)) {
                type = 5;
            } else {
                type = 4;
            }
        }
        q.put("type", type);
        q.put("typeName", typeName(type));

        Integer category = toInt(q.get("category"));
        if (category == null) {
            category = guessCategory(content, options);
        }
        q.put("category", category);

        if (toInt(q.get("difficulty")) == null) {
            q.put("difficulty", guessDifficulty(content, options, type));
        }
        if (q.get("score") == null) {
            q.put("score", type == 4 ? 10 : (type == 5 ? 25 : 5));
        }
    }

    private int guessCategory(String content, List<String> options) {
        String lower = content.toLowerCase(Locale.ROOT);
        String optionText = String.join(" ", options).toLowerCase(Locale.ROOT);
        if (containsAny(lower, PERSONALITY_WORDS)) return 2;
        if (containsAny(lower, LOGIC_WORDS)) return 3;
        if (containsAny(lower, BEHAVIOR_WORDS)) return 4;
        if (containsAny(lower, TECH_WORDS) || containsAny(optionText, TECH_WORDS)) return 1;
        return 5;
    }

    private int guessDifficulty(String content, List<String> options, Integer type) {
        int len = content.length();
        if (type == 5 || len > 260) return 3;
        if (type == 4 || len > 90 || options.size() >= 4) return 2;
        return 1;
    }

    // ================= AI 校正 =================

    private List<Map<String, Object>> classifyBatch(ModelProvider provider, String apiKey,
                                                    List<Map<String, Object>> slice, int offset) throws Exception {
        StringBuilder sb = new StringBuilder();
        sb.append("你是题库分类助手。为下列每道题判断题目分类与题型，只输出 JSON 数组，不要解释。\n");
        sb.append("分类取值：1专业题 2性格测试 3综合能力(行测) 4行为面试 5其他；");
        sb.append("题型取值：1单选 2多选 3判断 4简答 5编程/算法；难度取值：1简单 2中等 3困难。\n");
        sb.append("输出格式：[{\"i\":0,\"category\":1,\"type\":1,\"difficulty\":1}]\n\n");
        for (int i = 0; i < slice.size(); i++) {
            Map<String, Object> q = slice.get(i);
            sb.append("#").append(i).append(" 题干：").append(str(q.get("content")));
            List<String> options = asStringList(q.get("options"));
            if (!options.isEmpty()) {
                sb.append(" 选项：");
                for (int j = 0; j < options.size(); j++) {
                    sb.append((char) ('A' + j)).append(".").append(options.get(j)).append(" ");
                }
            }
            String answer = str(q.get("answer"));
            if (answer != null) sb.append(" 参考答案：").append(answer);
            sb.append("\n");
        }

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", provider.getMppModelName());
        List<Map<String, String>> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", "你只输出严格 JSON 数组，不含 Markdown 代码块。"));
        messages.add(Map.of("role", "user", "content", sb.toString()));
        body.put("messages", messages);
        body.put("temperature", 0.1);
        body.put("max_tokens", 800);

        HttpRequest request = HttpRequest.newBuilder(URI.create(provider.getMppApiUrl()))
                .timeout(Duration.ofSeconds(120))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + apiKey)
                .POST(HttpRequest.BodyPublishers.ofString(JSON.toJSONString(body)))
                .build();
        HttpResponse<String> resp = HTTP.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        if (resp.statusCode() != 200) {
            throw new IllegalStateException("HTTP " + resp.statusCode());
        }
        String answer = extractContent(resp.body());
        String jsonText = extractJsonArray(answer);
        List<Map<String, Object>> parsed = JSON.parseObject(jsonText, new com.alibaba.fastjson2.TypeReference<List<Map<String, Object>>>() {
        });
        List<Map<String, Object>> result = new ArrayList<>();
        if (parsed == null) return result;
        for (Map<String, Object> p : parsed) {
            int i = toInt(p.get("i")) == null ? -1 : toInt(p.get("i"));
            if (i < 0 || i >= slice.size()) continue;
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("index", offset + i);
            out.put("category", toCategory(p.get("category")));
            out.put("type", toInt(p.get("type")));
            out.put("typeName", typeName(toInt(p.get("type"))));
            out.put("difficulty", toInt(p.get("difficulty")));
            result.add(out);
        }
        return result;
    }

    private String extractContent(String respBody) {
        try {
            Map<String, Object> root = JSON.parseObject(respBody, Map.class);
            List<Map<String, Object>> choices = (List<Map<String, Object>>) root.get("choices");
            if (choices == null || choices.isEmpty()) return "";
            Map<String, Object> msg = (Map<String, Object>) choices.get(0).get("message");
            return msg == null ? "" : String.valueOf(msg.getOrDefault("content", ""));
        } catch (Exception e) {
            return "";
        }
    }

    private String extractJsonArray(String text) {
        if (text == null) return "[]";
        int start = text.indexOf('[');
        int end = text.lastIndexOf(']');
        if (start >= 0 && end > start) {
            return text.substring(start, end + 1);
        }
        return "[]";
    }

    private ModelProvider activeProvider() {
        try {
            // resolve() 已包含 status=0 与 api_key 非空双重校验；异常时降级为规则结果
            return agentModelClient.resolve();
        } catch (Exception e) {
            logger.error("activeProvider error", e);
            return null;
        }
    }

    private String decryptKey(String stored) {
        if (stored == null || !stored.startsWith(ENC_PREFIX)) return stored;
        try {
            byte[] all = Base64.getDecoder().decode(stored.substring(ENC_PREFIX.length()));
            byte[] iv = Arrays.copyOfRange(all, 0, 12);
            byte[] ct = Arrays.copyOfRange(all, 12, all.length);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, aesKey(), new GCMParameterSpec(128, iv));
            return new String(cipher.doFinal(ct), StandardCharsets.UTF_8);
        } catch (Exception e) {
            return null;
        }
    }

    private SecretKeySpec aesKey() throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(cryptoKey.getBytes(StandardCharsets.UTF_8));
        return new SecretKeySpec(digest, "AES");
    }

    // ================= 校验与工具 =================

    private String validate(Map<String, Object> body) {
        String content = str(body.get("content"));
        if (content == null || content.isBlank()) return "题干不能为空";
        Integer type = toInt(body.get("type"));
        if (type == null || type < 1 || type > 5) return "题型必须是 1-5";
        List<String> options = asStringList(body.get("options"));
        if ((type == 1 || type == 2) && options.size() < 2) return "单选/多选至少需要 2 个选项";
        String answer = str(body.get("answer"));
        if (answer == null || answer.isBlank()) return "答案不能为空";
        BigDecimal score = toScore(body.get("score"));
        if (score == null || score.compareTo(BigDecimal.ZERO) <= 0) return "分值必须大于 0";
        return null;
    }

    private String optionsJson(Map<String, Object> body) {
        Integer type = toInt(body.get("type"));
        if (type == null || (type != 1 && type != 2)) return null;
        List<String> options = asStringList(body.get("options"));
        return options.isEmpty() ? null : JSON.toJSONString(options);
    }

    private static boolean isOptionLike(String line) {
        Matcher m = OPTION_LINE.matcher(line);
        if (!m.matches()) return false;
        String letter = m.group(1);
        return letter != null && letter.length() == 1;
    }

    private static boolean isJudgeAnswer(String answer) {
        String a = answer.trim();
        return a.equals("对") || a.equals("错") || a.equals("正确") || a.equals("错误")
                || a.equalsIgnoreCase("T") || a.equalsIgnoreCase("F")
                || a.equals("√") || a.equals("×") || a.equals("是") || a.equals("否");
    }

    private static boolean containsAny(String text, String[] words) {
        if (text == null) return false;
        String lower = text.toLowerCase(Locale.ROOT);
        for (String w : words) {
            if (lower.contains(w.toLowerCase(Locale.ROOT))) return true;
        }
        return false;
    }

    private static int findCol(Map<String, Integer> col, String... keys) {
        for (Map.Entry<String, Integer> e : col.entrySet()) {
            String name = e.getKey() == null ? "" : e.getKey().trim().toLowerCase(Locale.ROOT);
            for (String k : keys) {
                if (name.equalsIgnoreCase(k) || name.contains(k.toLowerCase(Locale.ROOT))) {
                    return e.getValue();
                }
            }
        }
        return -1;
    }

    private static String cellText(Cell c) {
        if (c == null) return "";
        try {
            switch (c.getCellType()) {
                case STRING:
                    return c.getStringCellValue();
                case NUMERIC:
                    double d = c.getNumericCellValue();
                    return d == Math.floor(d) ? String.valueOf((long) d) : String.valueOf(d);
                case BOOLEAN:
                    return String.valueOf(c.getBooleanCellValue());
                case FORMULA:
                    return c.getCellFormula();
                default:
                    return "";
            }
        } catch (Exception e) {
            return "";
        }
    }

    private static int parseTypeText(String text) {
        String t = text == null ? "" : text.trim();
        if (t.contains("多选")) return 2;
        if (t.contains("单选") || t.contains("选择")) return 1;
        if (t.contains("判断")) return 3;
        if (t.contains("编程") || t.contains("算法")) return 5;
        if (t.contains("简答") || t.contains("问答")) return 4;
        return 1;
    }

    private static int parseCategoryText(String text) {
        String t = text == null ? "" : text.trim();
        if (t.contains("性格")) return 2;
        if (t.contains("综合") || t.contains("行测")) return 3;
        if (t.contains("行为") || t.contains("面试")) return 4;
        if (t.contains("专业")) return 1;
        return 5;
    }

    private static int toDifficulty(String text) {
        String t = text == null ? "" : text.trim();
        if (t.contains("难") || t.contains("高") || t.equals("3")) return 3;
        if (t.contains("中") || t.equals("2")) return 2;
        return 1;
    }

    private static String typeName(Integer type) {
        if (type == null) return "单选";
        switch (type) {
            case 2: return "多选";
            case 3: return "判断";
            case 4: return "简答";
            case 5: return "编程";
            default: return "单选";
        }
    }

    private static int toCategory(Object v) {
        int c = toInt(v) == null ? 1 : toInt(v);
        return (c >= 1 && c <= 5) ? c : 1;
    }

    private static String str(Object v) {
        return v == null ? null : String.valueOf(v).trim();
    }

    private static Integer toInt(Object v) {
        if (v == null) return null;
        try {
            if (v instanceof Number) return ((Number) v).intValue();
            String s = String.valueOf(v).trim();
            return s.isEmpty() ? null : (int) Double.parseDouble(s);
        } catch (Exception e) {
            return null;
        }
    }

    private static Long toLong(Object v) {
        if (v == null) return null;
        try {
            if (v instanceof Number) return ((Number) v).longValue();
            String s = String.valueOf(v).trim();
            return s.isEmpty() ? null : Long.parseLong(s);
        } catch (Exception e) {
            return null;
        }
    }

    private static BigDecimal toScore(Object v) {
        if (v == null) return null;
        try {
            if (v instanceof BigDecimal) return (BigDecimal) v;
            if (v instanceof Number) return BigDecimal.valueOf(((Number) v).doubleValue());
            String s = String.valueOf(v).trim();
            return s.isEmpty() ? null : new BigDecimal(s);
        } catch (Exception e) {
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> asList(Object v) {
        if (v instanceof List) return (List<Map<String, Object>>) v;
        return new ArrayList<>();
    }

    private static List<String> asStringList(Object v) {
        List<String> out = new ArrayList<>();
        if (v instanceof List) {
            for (Object o : (List<?>) v) {
                if (o != null) out.add(String.valueOf(o));
            }
        }
        return out;
    }

    /** 延迟持有 ObjectMapper，避免与 fastjson 混用。 */
    private static class ObjectMapperHolder {
    }
}
