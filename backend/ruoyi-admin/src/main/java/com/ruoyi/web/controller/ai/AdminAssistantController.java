package com.ruoyi.web.controller.ai;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Set;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.util.Arrays;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.ai.core.AgentActionStore;
import com.ruoyi.ai.core.AgentTool;
import com.ruoyi.ai.core.AgentToolPackage;
import com.ruoyi.ai.core.PendingAction;
import com.ruoyi.ai.core.PendingActionHandler;
import com.ruoyi.ai.core.ToolArgs;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;
import com.ruoyi.ai.audit.AgentStepRecorder;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.IModelProviderService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RestController;
import jakarta.servlet.http.HttpServletResponse;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.stream.Stream;

/**
 * 后台管理 AI 助手：只读工具直接查询，写工具生成草稿并在用户确认后执行。
 * 能力：RAG 知识库检索 + Function Calling 只读工具 + 路由跳转建议。
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/assistant")
public class AdminAssistantController extends BaseController {

    private static final String ENC_PREFIX = "ENC:";
    private static volatile ModelProvider cachedProvider;
    /** Provider selection has a single source: AgentModelClient.resolve() (status 1 = enabled, api_key non-blank). */
    private ModelProvider activeProvider() {
        if (cachedProvider != null) return cachedProvider;
        try {
            cachedProvider = agentModelClient.resolve();
            return cachedProvider;
        } catch (Exception e) {
            logger.error("resolve provider error", e);
            return null;
        }
    }

    @Value("${ai.model.crypto-key:Intelligent-Interviewer-AI@2026}")
    private String cryptoKey;

    private final IModelProviderService providerService;
    private final ObjectMapper json = new ObjectMapper();
    private final HttpClient http = buildClient();

    private static HttpClient buildClient() {
        try {
            javax.net.ssl.SSLContext sc = javax.net.ssl.SSLContext.getInstance("TLS");
            sc.init(null, new javax.net.ssl.TrustManager[]{new javax.net.ssl.X509TrustManager() {
                public java.security.cert.X509Certificate[] getAcceptedIssuers() { return new java.security.cert.X509Certificate[0]; }
                public void checkClientTrusted(java.security.cert.X509Certificate[] certs, String t) {}
                public void checkServerTrusted(java.security.cert.X509Certificate[] certs, String t) {}
            }}, new java.security.SecureRandom());
            return HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(15))
                    .sslContext(sc)
                    .sslParameters(buildNoVerifyParams(sc))
                    .build();
        } catch (Exception e) {
            return HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(15)).build();
        }
    }
    private static javax.net.ssl.SSLParameters buildNoVerifyParams(javax.net.ssl.SSLContext sc) {
        javax.net.ssl.SSLParameters p = sc.getDefaultSSLParameters();
        p.setEndpointIdentificationAlgorithm("");
        return p;
    }

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private KbEmbeddingService kbEmbedding;

    @Autowired
    private com.ruoyi.system.service.app.ai.AgentModelClient agentModelClient;

    /** 按端注册的工具包：工具 schema 与执行都从这里取，编排层不再关心具体有哪些工具。 */
    @Autowired
    private List<AgentToolPackage> toolPackages;

    @Autowired
    private AgentActionStore actionStore;

    /** 各端写工具自报的草稿执行器。 */
    @Autowired
    private List<PendingActionHandler> pendingHandlers;

    /** 工具调用审计：默认关闭，审计表执行后由配置打开。 */
    @Autowired
    private AgentStepRecorder stepRecorder;

    /** 单次对话内收集的待确认卡片（ThreadLocal，请求结束即清除）。 */
    private static final ThreadLocal<List<Map<String, Object>>> PENDING_CARDS =
            ThreadLocal.withInitial(ArrayList::new);

    /** 本端标识：只加载同 scope 的工具包，避免跨端串用。 */
    private static final String SCOPE = "admin";

    /** 兼容模型把工具调用写成文本标记（如 <｜｜DSML｜｜ invoke name="x">）的情况。 */
    private static final java.util.regex.Pattern TEXT_INVOKE_PATTERN =
            java.util.regex.Pattern.compile("<[^<>]*invoke\\s+name=\"([A-Za-z0-9_]+)\"([\\s\\S]*?)(?=<[^<>]*invoke\\s+name=\"|$)");
    private static final java.util.regex.Pattern TEXT_PARAM_PATTERN =
            java.util.regex.Pattern.compile("<[^<>]*parameter\\s+name=\"([A-Za-z0-9_]+)\"[^>]*>([^<]*)");
    private static final java.util.regex.Pattern TEXT_TAG_PATTERN =
            java.util.regex.Pattern.compile("<[^<>]*(?:invoke|parameter|calls|tool_call)[^<>]*>");

    /** 兼容 <tool_call name="x">JSON</tool_call> 与模型常写的 <tool_callname="x">JSON</tool_call>。 */
    private static final java.util.regex.Pattern TEXT_TOOL_CALL_PATTERN =
            java.util.regex.Pattern.compile("<tool_call\\s*name=\"([A-Za-z0-9_]+)\">([\\s\\S]*?)</tool_call>");

    public AdminAssistantController(IModelProviderService providerService) {
        this.providerService = providerService;
    }

    private static final String SYSTEM_PROMPT = """
            你是招聘管理系统后台AI助手。既能查业务数据，也能代用户起草题目、修改题目与调整分类。
            严格要求：
            0. 调用工具必须使用工具调用接口（tool_calls），禁止把调用写成任何文本标记或伪标签；
            1. 任何写操作都必须先调用 create_questions / update_questions / classify_questions / delete_questions / undo_import_batch / create_companies
               生成待确认草稿，然后告诉用户"请点击下方卡片确认"，绝不能声称已经写入、修改或已经撤销；
            2. 业务数字优先用工具查真实数据，不编造；
               岗位查询用 search_jobs（可按岗位名、企业、城市、状态筛选）；
               候选人/人才库用 search_talent（可按企业、状态、归档来源筛选，不返回联系方式）；
               消息模板用 list_message_templates（可按标题或编码、渠道、状态、企业筛选）；
            3. 中文简洁分点回答；
            4. 题库口径：分类 1-5；题型 1 单选、2 多选、3 判断、4 简答、5 编程；
            5. 用户问某题的答案、解析、选项或分值时，直接调用 get_question_detail（只读），
               不得凭 search_questions 的题干摘要猜测答案；回答必须完整列出题干与全部选项
               （按 A/B/C/D 逐条，不得省略、合并或只给部分），再给答案与解析；
               问是否有重复题时调用 check_duplicate_questions，结果只是相似度预检，不得据此断言两题完全相同；
            6. 用户明确给出题号并要求调整分类或题型时，直接调用 classify_questions，工具会自行核验；
               search_questions 只返回有限筛选结果，不得据此判断未列出的题号不存在；
            7. 用户明确给出题号并要求修改题干、答案、解析、难度或分值时，直接调用 update_questions；
               未指定题库时默认 platform，不得把平台题目修改写入企业题库；
            8. 用户明确要求删除题目时，直接调用 delete_questions；删除不可恢复，工具会自动保留被考卷或答卷
               引用的题，回复中必须说明保留数量，不得声称已删除；
            9. 用户问"在哪/怎么进"时，最后一行输出 [[route:path]]，path从以下选：
            /dashboard /company/company/list /company/user /business/list /business/verify
            /recruit/job /recruit/candidate /recruit/resume /recruit/interview /recruit/exam
            /msg/template /msg/record /msg/channel /msg/sent
            /ai/provider-list /ai/agent /ai/quota
            /system/role /system/menu /monitor/online /monitor/job /monitor/cache /monitor/operlog /monitor/logininfor
            /content/advert /content/question /content/feedback
            /question/platform
            10. 输出排版：结论放第一行；用「### 小标题」或「- 要点」组织，一条一行；
                段落之间最多一个空行，禁止连续空行与行尾空格；不把 JSON、工具名或参数原文贴给用户；
                不复述用户问题；简单查询不超过 8 行，复杂查询不超过 15 行，用户要求详细时除外。
            11. 附件处理：用户随消息带附件时，先读附件文本再判断意图：
                - 要求提取/整理题目：按题库口径整理成 items，调用 create_questions 生成草稿，默认 platform，不得编造附件未出现的题干、答案或选项；
                - 要求录入公司/企业：提取名称、信用代码、行业、规模、城市、地址、官网、简介、联系人、电话，调用 create_companies 生成草稿；
                - 其他要求：基于附件内容回答；附件里没有的信息一律留空，不得猜测。
            12. 修改类请求先定位对象再改：题目先用 search_questions 确认 questionId 再调用 update_questions；
                命中多条时先列候选让用户选择，不得批量修改不明确的记录。
            13. 名字以 mcp_ 开头的是外部 MCP 工具（由配置决定是否启用）：用户明确要求使用外部工具
                （点名 mcp_ 工具，或要求"用 echo 工具""调用外部工具"）时必须真的发起工具调用，
                不得用文字模拟调用结果；工具不存在或不可用时直接说明"当前没有该外部工具"。
            """;

    @PreAuthorize("@ss.hasPermi('system:ai:assistant')")
    @PostMapping("/chat")
    public AjaxResult chat(@RequestBody Map<String, Object> body) {
        String message = body.get("message") == null ? "" : body.get("message").toString().trim();
        if (message.isEmpty()) {
            return error("请输入问题");
        }
        @SuppressWarnings("unchecked")
        List<Map<String, String>> history = (List<Map<String, String>>) body.getOrDefault("history", new ArrayList<>());

        ModelProvider provider = activeProvider();
        if (provider == null) {
            return error("AI 模型未配置，请先在 AI 配置中启用模型");
        }
        String apiKey = decryptKey(provider.getMppApiKey());
        if (apiKey == null || apiKey.isBlank()) {
            return error("AI 模型密钥无效");
        }
        try {
            // 1) RAG：先检索知识库，命中则注入参考资料
            String ragCtx = searchKnowledge(message);

            ArrayNode messages = json.createArrayNode();
            String sysContent = SYSTEM_PROMPT + (ragCtx.isEmpty() ? "" : "\n\n【知识库参考资料】\n" + ragCtx);
            messages.addObject().put("role", "system").put("content", sysContent);
            String attachCtx = attachmentContext(body.get("attachments"), 6000);
            if (!attachCtx.isEmpty()) {
                messages.addObject().put("role", "system").put("content", attachCtx);
            }
            for (Map<String, String> h : history) {
                String r = h.get("role");
                String c = h.get("content");
                if (r != null && c != null && (r.equals("user") || r.equals("assistant"))) {
                    messages.addObject().put("role", r).put("content", c);
                }
            }
            messages.addObject().put("role", "user").put("content", message);

            // 2) 带工具请求：只读工具直查，写工具只生成待确认草稿
            PENDING_CARDS.remove();
            ArrayNode tools = buildTools();
            String answer = callModel(provider.getMppModelName(), provider.getMppApiUrl(), apiKey, messages, tools);

            Map<String, Object> data = new java.util.LinkedHashMap<>();
            data.put("answer", normalizeAnswer(answer));
            data.put("pendings", new ArrayList<>(PENDING_CARDS.get()));
            return success(data);
        } catch (Exception e) {
            logger.error("admin assistant chat error", e);
            return error("AI 助手暂时不可用：" + e.getMessage());
        } finally {
            PENDING_CARDS.remove();
        }
    }

    /** 流式端点：同步写 SSE（请求线程内完成，避免异步分发丢鉴权）。 */
    @PreAuthorize("@ss.hasPermi('system:ai:assistant')")
    @PostMapping(value = "/chat/stream", produces = "text/event-stream;charset=UTF-8")
    public void chatStream(HttpServletResponse response, @RequestBody Map<String, Object> body) throws Exception {
        String message = body.get("message") == null ? "" : body.get("message").toString().trim();
        @SuppressWarnings("unchecked")
        List<Map<String, String>> history = (List<Map<String, String>>) body.getOrDefault("history", new ArrayList<>());
        ModelProvider provider = activeProvider();
        response.setContentType("text/event-stream");
        response.setCharacterEncoding("UTF-8");
        response.setBufferSize(0);
        response.setHeader("Cache-Control", "no-cache");
        response.setHeader("X-Accel-Buffering", "no");
        java.io.PrintWriter out = response.getWriter();
        if (message.isEmpty() || provider == null) {
            out.write("data: [DONE]\n\n");
            out.flush();
            return;
        }
        String apiKey = decryptKey(provider.getMppApiKey());
        String model = provider.getMppModelName();
        String url = provider.getMppApiUrl();
        try {
            // 只传最近5条历史，减少token
            List<Map<String, String>> shortHistory = history.size() > 5
                    ? history.subList(history.size() - 5, history.size())
                    : history;
            ArrayNode messages = buildMessages(message, shortHistory, body.get("attachments"));

            // 题库类问题走工具路径：可查库、可生成待确认草稿；普通问答仍走流式
            if (needsQuestionTools(message)) {
                PENDING_CARDS.remove();
                ArrayNode tools = buildTools();
                String answer = callModel(model, url, apiKey, messages, tools);
                Map<String, Object> answerEvent = new java.util.LinkedHashMap<>();
                answerEvent.put("text", normalizeAnswer(answer));
                out.write("event: answer\ndata: " + json.writeValueAsString(answerEvent) + "\n\n");
                out.flush();
                List<Map<String, Object>> cards = new ArrayList<>(PENDING_CARDS.get());
                if (!cards.isEmpty()) {
                    out.write("event: pending\ndata: " + json.writeValueAsString(cards) + "\n\n");
                    out.flush();
                }
                PENDING_CARDS.remove();
                out.write("data: [DONE]\n\n");
                out.flush();
                return;
            }

            // 预判：需要工具时后端直接查SQL注入消息，省掉一轮非流式等模型判断
            boolean needTools = needsToolCall(message);
            if (needTools) {
                out.write("event: tool\ndata: 正在查询业务数据…\n\n");
                out.flush();
                StringBuilder stats = new StringBuilder(quickStats());
                // 尝试从问题中识别公司名，命中则注入该公司维度详细数据
                Long cmpId = matchCompany(message);
                if (cmpId != null) {
                    stats.append("\n【指定公司详细数据】\n").append(companyDetailStats(cmpId));
                }
                messages.addObject().put("role", "system").put("content",
                        "【实时业务数据】\n" + stats + "\n请基于以上真实数据回答用户问题，不要编造数字。如果用户问的是某家公司，就用【指定公司详细数据】里的数字回答。");
            }
            streamGenerate(model, url, apiKey, messages, out);
            out.write("data: [DONE]\n\n");
            out.flush();
        } catch (Exception e) {
            logger.error("assistant stream error", e);
            out.write("data: {\"error\":\"stream failed\"}\n\n");
            out.flush();
        }
    }

    /** 从问题中识别公司名：LIKE 模糊匹配 t_cmp.cmp_name，返回最匹配的 cmp_id。 */
    private Long matchCompany(String q) {
        try {
            if (q == null || q.length() < 2) return null;
            // 去掉常见干扰词
            String kw = q.replaceAll("(公司|企业|今天|今日|现在|目前|多少|几个|的|了|吗|呢|？|\\?|，|,|。|\\.)", " ").trim();
            if (kw.length() < 2) return null;
            // 取最长的一段作为候选
            String[] parts = kw.split("\\s+");
            String best = "";
            for (String p : parts) {
                if (p.length() >= 2 && p.length() > best.length()) best = p;
            }
            if (best.length() < 2) return null;
            List<Long> ids = jdbc.queryForList(
                    "SELECT cmp_id FROM t_cmp WHERE cmp_name LIKE ? ORDER BY cmp_id LIMIT 1",
                    Long.class, "%" + best + "%");
            return ids.isEmpty() ? null : ids.get(0);
        } catch (Exception e) {
            return null;
        }
    }

    /** 某公司维度的详细业务数据：岗位、投递、面试、通过率。 */
    private String companyDetailStats(Long cmpId) {
        try {
            String name = jdbc.queryForObject("SELECT cmp_name FROM t_cmp WHERE cmp_id=?", String.class, cmpId);
            Integer posTotal = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_pos WHERE pos_company_id=?", Integer.class, cmpId);
            Integer posOn = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_pos WHERE pos_company_id=? AND pos_status=1", Integer.class, cmpId);
            Integer todayApp = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_app_record a JOIN t_pos p ON a.app_position_id=p.pos_id " +
                    "WHERE p.pos_company_id=? AND a.app_created_at>=CURDATE()", Integer.class, cmpId);
            Integer totalApp = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_app_record a JOIN t_pos p ON a.app_position_id=p.pos_id " +
                    "WHERE p.pos_company_id=?", Integer.class, cmpId);
            Integer weekApp = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_app_record a JOIN t_pos p ON a.app_position_id=p.pos_id " +
                    "WHERE p.pos_company_id=? AND a.app_created_at>=DATE_SUB(NOW(),INTERVAL 7 DAY)", Integer.class, cmpId);
            Integer intvTotal = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_sch_appointment a JOIN t_pos p ON a.apt_position_id=p.pos_id " +
                    "WHERE p.pos_company_id=?", Integer.class, cmpId);
            Integer intvPass = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_sch_appointment a JOIN t_pos p ON a.apt_position_id=p.pos_id " +
                    "WHERE p.pos_company_id=? AND a.apt_status=1", Integer.class, cmpId);
            Integer intvPending = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_sch_appointment a JOIN t_pos p ON a.apt_position_id=p.pos_id " +
                    "WHERE p.pos_company_id=? AND a.apt_status=0 AND a.apt_start_time>=NOW()", Integer.class, cmpId);
            String passRate = (intvTotal == null || intvTotal == 0) ? "暂无面试记录"
                    : String.format("%.1f%%", intvPass * 100.0 / intvTotal);
            return String.join("\n",
                    "公司名称=" + name,
                    "岗位总数=" + posTotal + "（上架" + posOn + "）",
                    "今日新投递=" + todayApp + "份",
                    "近7天投递=" + weekApp + "份，累计投递=" + totalApp + "份",
                    "面试总数=" + intvTotal + "场（通过=" + intvPass + "，待面试=" + intvPending + "）",
                    "面试通过率=" + passRate);
        } catch (Exception e) {
            return "公司详情查询失败：" + e.getMessage();
        }
    }

    /** 后端直接查业务统计，不用模型function calling。 */
    private String quickStats() {
        try {
            Integer pos = jdbc.queryForObject("SELECT COUNT(*) FROM t_pos", Integer.class);
            Integer posOn = jdbc.queryForObject("SELECT COUNT(*) FROM t_pos WHERE pos_status=1", Integer.class);
            Integer posOff = jdbc.queryForObject("SELECT COUNT(*) FROM t_pos WHERE pos_status IN (2,3)", Integer.class);
            Integer tal = jdbc.queryForObject("SELECT COUNT(*) FROM t_tal", Integer.class);
            Integer cmp = jdbc.queryForObject("SELECT COUNT(*) FROM t_cmp", Integer.class);
            Integer cmpPending = jdbc.queryForObject("SELECT COUNT(*) FROM t_cmp WHERE cmp_verify_status=0", Integer.class);
            Integer recentTal = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_tal WHERE tal_created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)", Integer.class);
            Integer recentApp = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM t_app_record WHERE app_created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)", Integer.class);
            Integer todayLogin = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM sys_logininfor WHERE login_time >= CURDATE()", Integer.class);
            Integer todayFail = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM sys_logininfor WHERE status='1' AND login_time >= CURDATE()", Integer.class);
            List<Map<String,Object>> topCmp = jdbc.queryForList(
                    "SELECT c.cmp_name, COUNT(p.pos_id) AS cnt FROM t_cmp c LEFT JOIN t_pos p ON c.cmp_id=p.pos_company_id AND p.pos_status=1 GROUP BY c.cmp_id ORDER BY cnt DESC LIMIT 3");
            StringBuilder sb = new StringBuilder();
            sb.append("岗位总数=").append(pos).append("（上架").append(posOn).append("，下架").append(posOff).append("）；");
            sb.append("候选人总数=").append(tal).append("，近7天新增=").append(recentTal).append("；");
            sb.append("企业总数=").append(cmp).append("，待审核=").append(cmpPending).append("；");
            sb.append("近7天投递=").append(recentApp).append("；");
            sb.append("今日登录=").append(todayLogin).append("次，失败=").append(todayFail).append("次；");
            sb.append("岗位数TOP3企业=");
            for (int i = 0; i < topCmp.size(); i++) {
                Map<String,Object> r = topCmp.get(i);
                sb.append(r.get("cmp_name")).append("(").append(r.get("cnt")).append("岗");
                sb.append(i < topCmp.size()-1 ? "，" : "");
            }
            return sb.toString();
        } catch (Exception e) {
            return "统计查询失败：" + e.getMessage();
        }
    }

    /** 简单关键词预判：只有涉及业务数据查询才走工具调用，否则直接流式回答。 */
    private boolean needsToolCall(String q) {
        if (q == null) return false;
        String[] keywords = {"多少", "几个", "统计", "总数", "异常", "失败", "登录", "数据", "数量", "新增",
                "最近", "多少家", "多少人", "多少岗位", "多少候选人", "审核", "待审", "上架", "下架",
                "企业", "公司", "投递", "面试", "入职", "通过", "拒绝", "top", "排行", "分布", "状态"};
        for (String kw : keywords) {
            if (q.contains(kw)) return true;
        }
        return false;
    }

    /** 题库相关意图：这类问题需要带工具跑，才能查到真实题目或生成待确认草稿。 */
    private boolean needsQuestionTools(String q) {
        if (q == null) return false;
        String[] keywords = {"题库", "题目", "出题", "出几道", "生成题", "加题", "新增题", "导入记录",
                "撤销", "批次", "改分类", "分类调整", "查重", "重复题", "题型", "题干",
                "修改题", "改题", "答案", "解析", "难度", "分值", "选项",
                "删除题", "删题", "移除题", "清除题", "删除", "删掉", "移除", "清除",
                "附件", "这个文件", "这份文档", "提取题", "整理题", "录入", "新增企业", "企业信息", "公司信息", "导入企业",
                "岗位", "候选人", "人才库", "消息模板", "模板", "mcp", "MCP", "外部工具"};
        for (String kw : keywords) {
            if (q.contains(kw)) return true;
        }
        return false;
    }

    /** 用户确认后执行待确认动作；写权限复用题库新增权限。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/pending/apply")
    public AjaxResult applyPending(@RequestBody Map<String, Object> body) {
        String id = body.get("id") == null ? "" : body.get("id").toString();
        if (id.isBlank()) {
            return error("缺少待确认编号");
        }
        PendingAction action = actionStore.take(id);
        if (action == null) {
            return error("草稿已过期或已提交，请让助手重新生成");
        }
        if (!SCOPE.equals(action.scope)) {
            return error("该草稿不属于当前端，无法执行");
        }
        try {
            for (PendingActionHandler handler : pendingHandlers) {
                if (handler.supports(action)) {
                    return success(handler.apply(action, toolContext()));
                }
            }
            return error("没有可执行该草稿的工具");
        } catch (Exception e) {
            logger.error("apply pending error id={}", id, e);
            return error("执行失败：" + e.getMessage());
        }
    }

    /** 放弃待确认动作（用户点"取消"）。 */
    @PreAuthorize("@ss.hasPermi('system:ai:assistant')")
    @PostMapping("/pending/discard")
    public AjaxResult discardPending(@RequestBody Map<String, Object> body) {
        String id = body.get("id") == null ? "" : body.get("id").toString();
        return success(Map.of("discarded", actionStore.discard(id)));
    }

    /** 把随消息上传的附件文本整理为上下文；总量受限，避免挤压对话预算。 */
    private String attachmentContext(Object raw, int limit) {
        if (!(raw instanceof List<?> list) || list.isEmpty()) return "";
        StringBuilder sb = new StringBuilder();
        int total = 0;
        for (Object o : list) {
            if (!(o instanceof Map<?, ?> m)) continue;
            String name = m.get("name") == null ? "附件" : String.valueOf(m.get("name"));
            String text = m.get("text") == null ? "" : String.valueOf(m.get("text")).trim();
            if (text.isEmpty() || total >= limit) continue;
            int room = Math.min(2000, limit - total);
            if (text.length() > room) {
                text = text.substring(0, room) + "\n…（已截断）";
            }
            sb.append("\n### 附件：").append(name).append('\n').append(text).append('\n');
            total += text.length();
        }
        return sb.length() == 0 ? "" : "【用户随消息上传的附件内容】" + sb;
    }

    private ArrayNode buildMessages(String message, List<Map<String, String>> history, Object attachRaw) throws Exception {
        ArrayNode messages = json.createArrayNode();
        String ragCtx = searchKnowledge(message);
        String sysContent = SYSTEM_PROMPT + (ragCtx.isEmpty() ? "" : "\n\n【知识库参考资料】\n" + ragCtx);
        messages.addObject().put("role", "system").put("content", sysContent);
        String attachCtx = attachmentContext(attachRaw, 6000);
        if (!attachCtx.isEmpty()) {
            messages.addObject().put("role", "system").put("content", attachCtx);
        }
        for (Map<String, String> h : history) {
            String r = h.get("role");
            String c = h.get("content");
            if (r != null && c != null && (r.equals("user") || r.equals("assistant"))) {
                messages.addObject().put("role", r).put("content", c);
            }
        }
        messages.addObject().put("role", "user").put("content", message);
        return messages;
    }

    /** 单轮非流式调用，返回响应根节点。 */
    private JsonNode callOnce(String model, String url, String apiKey, ArrayNode messages, ArrayNode tools, boolean withTools) throws Exception {
        ObjectNode reqBody = json.createObjectNode();
        reqBody.put("model", model);
        reqBody.set("messages", messages);
        reqBody.put("stream", false);
        reqBody.put("temperature", 0.3);
        reqBody.put("max_tokens", withTools && tools != null ? 3000 : 1024);
        if (withTools && tools != null && tools.size() > 0) {
            reqBody.set("tools", tools);
        }
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(280))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + apiKey)
                .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(reqBody)))
                .build();
        HttpResponse<String> resp = http.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        return json.readTree(resp.body());
    }

    private String toolLabel(String name) {
        switch (name == null ? "" : name) {
            case "get_dashboard_stats": return "正在查询岗位/候选人统计…";
            case "get_recent_login_alerts": return "正在查询最近登录异常…";
            default: return "正在调用工具…";
        }
    }

    /** 流式调用：逐行读 ARK SSE，把 delta.content 写成 SSE 行给前端。 */
    private void streamGenerate(String model, String url, String apiKey, ArrayNode messages, java.io.PrintWriter out) throws Exception {
        logger.info("streamGenerate model={} url={} msgs={}", model, url, messages.size());
        ObjectNode reqBody = json.createObjectNode();
        reqBody.put("model", model);
        reqBody.set("messages", messages);
        reqBody.put("stream", true);
        reqBody.put("temperature", 0.3);
        reqBody.put("max_tokens", 2048);
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + apiKey)
                .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(reqBody)))
                .build();
        HttpResponse<Stream<String>> resp = http.send(request, HttpResponse.BodyHandlers.ofLines());
        int status = resp.statusCode();
        if (status != 200) {
            StringBuilder errBody = new StringBuilder();
            resp.body().forEach(errBody::append);
            logger.error("ark stream http {} body={}", status, errBody);
            out.write("data: {\"error\":\"模型服务异常(" + status + ")\"}\n\n");
            out.flush();
            return;
        }
        try (Stream<String> lines = resp.body()) {
            for (String line : (Iterable<String>) lines::iterator) {
                logger.info("ark raw: {}", line);
                if (!line.startsWith("data:")) continue;
                String data = line.substring(5).trim();
                if (data.isEmpty() || "[DONE]".equals(data)) continue;
                JsonNode node = json.readTree(data);
                String delta = node.path("choices").path(0).path("delta").path("content").asText("");
                if (!delta.isEmpty()) {
                    // JSON 编码后再写入：正文含换行时不会破坏 SSE 帧，前端可原样还原
                    out.write("data: " + json.writeValueAsString(delta) + "\n\n");
                    out.flush();
                }
            }
        }
    }

    /** 调模型；若返回 tool_calls 则执行工具后二次请求。 */
    private String callModel(String model, String url, String apiKey, ArrayNode messages, ArrayNode tools) throws Exception {
        ObjectNode reqBody = json.createObjectNode();
        reqBody.put("model", model);
        reqBody.set("messages", messages);
        reqBody.put("stream", false);
        reqBody.put("temperature", 0.3);
        reqBody.put("max_tokens", tools != null && tools.size() > 0 ? 3000 : 1024);
        reqBody.set("thinking", json.createObjectNode().put("type", "disabled"));
        if (tools != null && tools.size() > 0) {
            reqBody.set("tools", tools);
        }

        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(280))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + apiKey)
                .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(reqBody)))
                .build();
        HttpResponse<String> resp = http.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        if (resp.statusCode() != 200) {
            return "（模型调用失败 HTTP " + resp.statusCode() + "）";
        }
        JsonNode root = json.readTree(resp.body());
        JsonNode msg = root.path("choices").path(0).path("message");
        JsonNode toolCalls = msg.path("tool_calls");

        // 无工具调用：先看模型是否把调用写成了文本标记，命中则按工具流程执行
        if (toolCalls.isMissingNode() || !toolCalls.isArray() || toolCalls.size() == 0) {
            String raw = msg.path("content").asText("");
            List<ObjectNode> textCalls = parseTextToolCalls(raw);
            if (textCalls.isEmpty()) {
                return raw;
            }
            ObjectNode assistantMsg = json.createObjectNode();
            assistantMsg.put("role", "assistant");
            String cleaned = TEXT_TAG_PATTERN.matcher(raw).replaceAll("").trim();
            assistantMsg.put("content", cleaned.isEmpty() ? "（已调用工具）" : cleaned);
            messages.add(assistantMsg);
            // 文本形式没有 tool_call_id，不能拼 role=tool 消息（模型会 400），改为注入工具结果
            StringBuilder results = new StringBuilder("【工具执行结果】\n");
            for (ObjectNode call : textCalls) {
                String name = call.path("function").path("name").asText("");
                String args = call.path("function").path("arguments").asText("{}");
                results.append("- ").append(name).append(" → ").append(executeTool(name, args)).append("\n");
            }
            results.append("\n请基于以上工具结果回答用户，不要再输出任何工具标记文本。");
            messages.addObject().put("role", "user").put("content", results.toString());
            return callModel(model, url, apiKey, messages, null);
        }

        // 有工具调用：把 assistant(tool_calls) 消息追加，逐个执行工具
        messages.add(msg);
        for (JsonNode call : toolCalls) {
            String name = call.path("function").path("name").asText("");
            String args = call.path("function").path("arguments").asText("{}");
            String result = executeTool(name, args);
            ObjectNode toolMsg = json.createObjectNode();
            toolMsg.put("role", "tool");
            toolMsg.put("tool_call_id", call.path("id").asText(""));
            toolMsg.put("name", name);
            toolMsg.put("content", result);
            messages.add(toolMsg);
        }
        // 二次请求，不再带工具
        return callModel(model, url, apiKey, messages, null);
    }

    /** 从文本里解析出工具调用列表；解析不到返回空。 */
    private List<ObjectNode> parseTextToolCalls(String text) throws Exception {
        List<ObjectNode> calls = new ArrayList<>();
        if (text == null || text.isEmpty()) {
            return calls;
        }
        int seq = 0;
        // 先解析 <tool_call name="x">{...}</tool_call>（含无空格的 <tool_callname="x">）
        java.util.regex.Matcher tc = TEXT_TOOL_CALL_PATTERN.matcher(text);
        while (tc.find()) {
            String body = tc.group(2).trim();
            ObjectNode args = json.createObjectNode();
            if (body.startsWith("{")) {
                try {
                    JsonNode parsed = json.readTree(body);
                    if (parsed != null && parsed.isObject()) {
                        args = (ObjectNode) parsed;
                    }
                } catch (Exception ignore) {
                    // 非法 JSON 按空参数处理，交给工具自身兜底
                }
            }
            ObjectNode call = json.createObjectNode();
            call.put("id", "text_call_" + (++seq));
            ObjectNode fn = call.putObject("function");
            fn.put("name", tc.group(1));
            fn.put("arguments", json.writeValueAsString(args));
            calls.add(call);
        }
        java.util.regex.Matcher inv = TEXT_INVOKE_PATTERN.matcher(text);
        while (inv.find()) {
            String name = inv.group(1);
            ObjectNode args = json.createObjectNode();
            java.util.regex.Matcher pm = TEXT_PARAM_PATTERN.matcher(inv.group(2));
            while (pm.find()) {
                String key = pm.group(1);
                String value = pm.group(2).trim();
                if (value.startsWith("[") || value.contains(",")) {
                    ArrayNode arr = parseArrayValue(value);
                    if (arr != null) {
                        args.set(key, arr);
                        continue;
                    }
                }
                args.put(key, value);
            }
            ObjectNode call = json.createObjectNode();
            call.put("id", "text_call_" + (++seq));
            ObjectNode fn = call.putObject("function");
            fn.put("name", name);
            fn.put("arguments", json.writeValueAsString(args));
            calls.add(call);
        }
        return calls;
    }

    /** 把 [1,2] 或 1,2 或 1、2 解析成数组；不是数字列表则返回 null。 */
    private ArrayNode parseArrayValue(String raw) {
        String v = raw.trim();
        if (v.startsWith("[") && v.endsWith("]")) {
            try {
                JsonNode node = json.readTree(v);
                if (node != null && node.isArray()) {
                    return (ArrayNode) node;
                }
            } catch (Exception ignore) {
                // 非法 JSON 继续按逗号切分
            }
            v = v.substring(1, v.length() - 1);
        }
        ArrayNode arr = json.createArrayNode();
        boolean any = false;
        for (String part : v.split("[,，、\\s]+")) {
            String p = part.trim().replace("\"", "");
            if (p.matches("-?\\d+")) {
                arr.add(Long.parseLong(p));
                any = true;
            }
        }
        return any ? arr : null;
    }

    /** 工具定义全部由工具包提供，编排层不再手写 schema。 */
    private ArrayNode buildTools() {
        ArrayNode tools = json.createArrayNode();
        for (AgentToolPackage pkg : toolPackages) {
            if (SCOPE.equals(pkg.scope())) {
                tools.addAll(pkg.definitions(json));
            }
        }
        return tools;
    }

    private AgentTool findTool(String name) {
        for (AgentToolPackage pkg : toolPackages) {
            if (!SCOPE.equals(pkg.scope())) {
                continue;
            }
            AgentTool tool = pkg.find(name);
            if (tool != null) {
                return tool;
            }
        }
        return null;
    }

    private ToolContext toolContext() {
        return ToolContext.of(SCOPE, operatorName());
    }

    /** 执行工具：在工具包里按名查找并执行。写工具只登记草稿，不产生业务副作用。 */
    /** 输出规范化：压缩多余空行、去行尾空格、清除残留的伪工具标签。 */
    private String normalizeAnswer(String text) {
        if (text == null) return "";
        String s = text.replace("\r\n", "\n").replaceAll("[ \t]+\n", "\n");
        s = s.replaceAll("(?is)<tool_call[^>]*>.*?</tool_call>", "");
        s = TEXT_TAG_PATTERN.matcher(s).replaceAll("");
        s = s.replaceAll("\n{3,}", "\n\n").trim();
        return s.isEmpty() ? "（没有可展示的回答内容，请重试）" : s;
    }

    private String executeTool(String name, String args) {
        long start = System.currentTimeMillis();
        ToolContext ctx = toolContext();
        try {
            logger.debug("assistant tool call name={} argsLen={} args={}", name,
                    args == null ? 0 : args.length(),
                    args != null && args.length() > 1000 ? args.substring(0, 1000) : args);
            AgentTool tool = findTool(name);
            if (tool == null) {
                return "未知工具";
            }
            ToolResult result = tool.execute(ctx, ToolArgs.parse(json, args));
            if (result.hasPending()) {
                collectPendingCard(result.getPending());
            }
            stepRecorder.record(ctx, name, args, result.getText(), 0,
                    System.currentTimeMillis() - start,
                    result.hasPending() ? result.getPending().id : null);
            return result.getText();
        } catch (Exception e) {
            stepRecorder.record(ctx, name, args, e.getMessage(), 1,
                    System.currentTimeMillis() - start, null);
            return "工具查询失败：" + e.getMessage();
        }
    }

    private String operatorName() {
        try {
            String username = com.ruoyi.common.utils.SecurityUtils.getUsername();
            return username == null || username.isBlank() ? "system" : username;
        } catch (Exception e) {
            return "system";
        }
    }

    /** 草稿直接转前端确认卡片，不再从工具文本里反解析 pendingId。 */
    private void collectPendingCard(PendingAction action) {
        Map<String, Object> card = new java.util.LinkedHashMap<>();
        card.put("id", action.id);
        card.put("kind", action.kind);
        card.put("title", action.title);
        card.put("summary", action.summary);
        PENDING_CARDS.get().add(card);
    }

    /** RAG：优先向量语义检索，fallback全文索引，返回Top3相关知识。 */
    private String searchKnowledge(String q) {
        try {
            if (q == null || q.trim().length() < 2) return "";
            // 1) 优先用向量语义检索（真RAG）
            List<String> vecResults = kbEmbedding.search(q, 3);
            if (!vecResults.isEmpty()) {
                StringBuilder sb = new StringBuilder();
                for (String c : vecResults) sb.append("参考资料：").append(c).append("\n");
                return sb.toString();
            }
            // 2) fallback：全文索引
            String expanded = expandSynonyms(q);
            List<Map<String, Object>> rows = jdbc.queryForList(
                    "SELECT question, answer, MATCH(question,answer) AGAINST (? IN NATURAL LANGUAGE MODE) AS score " +
                    "FROM t_ai_knowledge " +
                    "WHERE MATCH(question,answer) AGAINST (? IN NATURAL LANGUAGE MODE) " +
                    "ORDER BY score DESC LIMIT 3", expanded, expanded);
            if (rows.isEmpty()) return "";
            StringBuilder sb = new StringBuilder();
            for (Map<String, Object> r : rows) {
                sb.append("Q: ").append(r.get("question")).append("\nA: ").append(r.get("answer")).append("\n");
            }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    /** 把问题里的词去同义词表扩展，返回一个空格分隔的搜索串（MySQL全文模式）。 */
    private String expandSynonyms(String q) {
        StringBuilder all = new StringBuilder(q);
        try {
            // 取所有同义词对，看用户问题里有没有命中原词
            List<Map<String, Object>> pairs = jdbc.queryForList("SELECT word, synonyms FROM t_ai_synonym");
            for (Map<String, Object> p : pairs) {
                String word = String.valueOf(p.get("word"));
                if (q.contains(word)) {
                    for (String s : String.valueOf(p.get("synonyms")).split(",")) {
                        all.append(" ").append(s.trim());
                    }
                }
            }
        } catch (Exception ignored) {}
        // 去掉标点，全文检索用空格分隔
        return all.toString().replaceAll("[，。？！、,\\.\\?\\!]", " ").trim();
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
        byte[] digest = MessageDigest.getInstance("SHA-256")
                .digest(cryptoKey.getBytes(StandardCharsets.UTF_8));
        return new SecretKeySpec(digest, "AES");
    }
}
