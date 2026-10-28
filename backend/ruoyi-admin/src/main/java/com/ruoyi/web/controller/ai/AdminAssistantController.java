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
 * 后台管理 AI 助手：只读问答，不做任何写操作。
 * 能力：RAG 知识库检索 + Function Calling 只读工具 + 路由跳转建议。
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/assistant")
public class AdminAssistantController extends BaseController {

    private static final String ENC_PREFIX = "ENC:";
    private static volatile ModelProvider cachedProvider;
    private ModelProvider activeProvider() {
        if (cachedProvider != null) return cachedProvider;
        try {
            List<Long> ids = jdbc.queryForList(
                    "SELECT mpp_id FROM t_model_provider WHERE mpp_status = 0 " +
                    "ORDER BY (mpp_api_url LIKE '%volces.com%') DESC, mpp_id LIMIT 1",
                    Long.class);
            if (ids.isEmpty()) {
                List<Long> any = jdbc.queryForList(
                        "SELECT mpp_id FROM t_model_provider ORDER BY mpp_id LIMIT 1", Long.class);
                if (any.isEmpty()) return null;
                cachedProvider = providerService.selectModelProviderByMppId(any.get(0));
            } else {
                cachedProvider = providerService.selectModelProviderByMppId(ids.get(0));
            }
            return cachedProvider;
        } catch (Exception e) {
            logger.error("activeProvider error", e);
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

    public AdminAssistantController(IModelProviderService providerService) {
        this.providerService = providerService;
    }

    private static final String SYSTEM_PROMPT = """
            你是招聘管理系统后台AI助手。介绍模块用途、操作指引，用只读工具查业务数据。
            严格要求：
            1. 只问答和只读查询，不执行写操作；
            2. 业务数字优先用工具查真实数据，不编造；
            3. 中文简洁分点回答；
            4. 用户问"在哪/怎么进"时，最后一行输出 [[route:path]]，path从以下选：
            /dashboard /company/company/list /company/user /business/list /business/verify
            /recruit/job /recruit/candidate /recruit/resume /recruit/interview /recruit/exam
            /msg/template /msg/record /msg/channel /msg/sent
            /ai/provider-list /ai/agent /ai/quota
            /system/role /system/menu /monitor/online /monitor/job /monitor/cache /monitor/operlog /monitor/logininfor
            /content/advert /content/question /content/feedback
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
            for (Map<String, String> h : history) {
                String r = h.get("role");
                String c = h.get("content");
                if (r != null && c != null && (r.equals("user") || r.equals("assistant"))) {
                    messages.addObject().put("role", r).put("content", c);
                }
            }
            messages.addObject().put("role", "user").put("content", message);

            // 2) 第一次请求：带只读工具定义
            ArrayNode tools = buildTools();
            String answer = callModel(provider.getMppModelName(), provider.getMppApiUrl(), apiKey, messages, tools);

            return success(Map.of("answer", answer == null ? "" : answer));
        } catch (Exception e) {
            logger.error("admin assistant chat error", e);
            return error("AI 助手暂时不可用：" + e.getMessage());
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
            ArrayNode messages = buildMessages(message, shortHistory);

            // 预判：需要工具时后端直接查SQL注入消息，省掉一轮非流式等模型判断
            boolean needTools = needsToolCall(message);
            if (needTools) {
                out.write("event: tool\ndata: 正在查询业务数据…\n\n");
                out.flush();
                String stats = quickStats();
                messages.addObject().put("role", "system").put("content",
                        "【实时业务数据】\n" + stats + "\n请基于以上真实数据回答用户问题，不要编造数字。");
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

    private ArrayNode buildMessages(String message, List<Map<String, String>> history) throws Exception {
        ArrayNode messages = json.createArrayNode();
        String ragCtx = searchKnowledge(message);
        String sysContent = SYSTEM_PROMPT + (ragCtx.isEmpty() ? "" : "\n\n【知识库参考资料】\n" + ragCtx);
        messages.addObject().put("role", "system").put("content", sysContent);
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
        reqBody.put("max_tokens", 1024);
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
        reqBody.put("max_tokens", 1024);
        HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(280))
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
                    out.write("data: " + delta + "\n\n");
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
        reqBody.put("max_tokens", 1024);
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

        // 无工具调用，直接返回内容
        if (toolCalls.isMissingNode() || !toolCalls.isArray() || toolCalls.size() == 0) {
            return msg.path("content").asText("");
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

    /** 只读工具定义。 */
    private ArrayNode buildTools() {
        ArrayNode tools = json.createArrayNode();

        ObjectNode p1 = json.createObjectNode();
        p1.put("type", "object");
        p1.set("properties", json.createObjectNode());
        ObjectNode t1 = json.createObjectNode();
        t1.put("type", "function");
        ObjectNode f1 = t1.putObject("function");
        f1.put("name", "get_dashboard_stats");
        f1.put("description", "查询平台真实业务统计：岗位总数、候选人总数、最近7天新增候选人");
        f1.set("parameters", p1);

        ObjectNode p2 = json.createObjectNode();
        p2.put("type", "object");
        p2.set("properties", json.createObjectNode());
        ObjectNode t2 = json.createObjectNode();
        t2.put("type", "function");
        ObjectNode f2 = t2.putObject("function");
        f2.put("name", "get_recent_login_alerts");
        f2.put("description", "查询最近的登录失败/异常记录，用于安全诊断");
        f2.set("parameters", p2);

        tools.add(t1);
        tools.add(t2);
        return tools;
    }

    /** 执行只读工具，任何异常都吞掉返回说明，绝不写库。 */
    private String executeTool(String name, String args) {
        try {
            switch (name) {
                case "get_dashboard_stats": {
                    Integer pos = jdbc.queryForObject("SELECT COUNT(*) FROM t_pos", Integer.class);
                    Integer tal = jdbc.queryForObject("SELECT COUNT(*) FROM t_tal", Integer.class);
                    Integer recent = jdbc.queryForObject(
                            "SELECT COUNT(*) FROM t_tal WHERE tal_created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)",
                            Integer.class);
                    return "岗位总数=" + pos + "；候选人总数=" + tal + "；近7天新增候选人=" + recent;
                }
                case "get_recent_login_alerts": {
                    List<Map<String, Object>> rows = jdbc.queryForList(
                            "SELECT login_name, ipaddr, msg, login_time FROM sys_logininfor " +
                            "WHERE status = '1' ORDER BY login_time DESC LIMIT 5");
                    if (rows.isEmpty()) return "最近没有登录失败记录";
                    StringBuilder sb = new StringBuilder("最近登录失败记录：\n");
                    for (Map<String, Object> r : rows) {
                        sb.append("- ").append(r.get("login_time")).append(" 用户=").append(r.get("login_name"))
                          .append(" IP=").append(r.get("ipaddr")).append(" 原因=").append(r.get("msg")).append("\n");
                    }
                    return sb.toString();
                }
                default:
                    return "未知工具";
            }
        } catch (Exception e) {
            return "工具查询失败：" + e.getMessage();
        }
    }

    /** RAG：关键词检索知识库，返回前 3 条命中。 */
    private String searchKnowledge(String q) {
        try {
            String kw = q.replaceAll("[%_]", "").trim();
            if (kw.length() < 2) return "";
            String like = "%" + kw.substring(0, Math.min(kw.length(), 12)) + "%";
            List<Map<String, Object>> rows = jdbc.queryForList(
                    "SELECT question, answer FROM t_ai_knowledge " +
                    "WHERE question LIKE ? OR answer LIKE ? ORDER BY kb_id DESC LIMIT 3", like, like);
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
