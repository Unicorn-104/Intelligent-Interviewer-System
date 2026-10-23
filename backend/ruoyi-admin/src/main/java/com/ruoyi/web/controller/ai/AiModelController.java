package com.ruoyi.web.controller.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.service.IModelProviderService;
import com.ruoyi.system.domain.ModelProvider;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.net.HttpURLConnection;
import java.net.URI;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.*;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

/**
 * AI模型配置（对齐前端 /ai/model 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/model")
public class AiModelController extends BaseController {

    @Autowired
    private IModelProviderService modelProviderService;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private static final String ENC_PREFIX = "ENC:";

    @Value("${ai.model.crypto-key:Intelligent-Interviewer-AI@2026}")
    private String cryptoKey;

    /** 加密 API Key，返回 ENC:Base64(IV+GCM密文)；已是密文则原样返回 */
    private String encryptKey(String plain) {
        if (plain == null || plain.isEmpty() || plain.startsWith(ENC_PREFIX)) return plain;
        try {
            byte[] iv = new byte[12];
            new SecureRandom().nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, aesKey(), new GCMParameterSpec(128, iv));
            byte[] enc = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));
            byte[] all = new byte[12 + enc.length];
            System.arraycopy(iv, 0, all, 0, 12);
            System.arraycopy(enc, 0, all, 12, enc.length);
            return ENC_PREFIX + Base64.getEncoder().encodeToString(all);
        } catch (Exception e) {
            throw new ServiceException("API Key 加密失败");
        }
    }

    /** 解密；无前缀视为旧明文原样返回，解密失败返回 null */
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

    /** 脱敏 API Key：前4后4（先解密再脱敏） */
    private String maskKey(String stored) {
        String plain = decryptKey(stored);
        if (plain == null) return null;
        if (plain.length() <= 8) return plain;
        return plain.substring(0, 4) + "****" + plain.substring(plain.length() - 4);
    }

    /** 解析 paramsJson 为 Map，失败返回空 */
    private Map<String, Object> parseParams(String json) {
        Map<String, Object> out = new HashMap<>();
        if (json == null || json.isEmpty()) return out;
        try {
            JsonNode node = objectMapper.readTree(json);
            node.fields().forEachRemaining(e -> out.put(e.getKey(), e.getValue().isValueNode()
                    ? e.getValue().asText(null) : e.getValue()));
        } catch (Exception ignored) {
        }
        return out;
    }

    @PreAuthorize("@ss.hasPermi('ai:model:list')")
    @GetMapping("/list")
    public TableDataInfo list(ModelProvider modelProvider,
                              @RequestParam(required = false) String modelName,
                              @RequestParam(required = false) String provider) {
        startPage();
        if (modelName != null && !modelName.isEmpty()) {
            modelProvider.setMppName(modelName);
        }
        List<ModelProvider> list = modelProviderService.selectModelProviderList(modelProvider);

        List<Map<String, Object>> result = new ArrayList<>();
        for (ModelProvider m : list) {
            Map<String, Object> p = parseParams(m.getMppParamsJson());
            // provider 存于 paramsJson，做内存过滤
            if (provider != null && !provider.isEmpty()
                    && !provider.equals(String.valueOf(p.getOrDefault("provider", "other")))) {
                continue;
            }
            Map<String, Object> item = new HashMap<>();
            item.put("modelId", m.getMppId());
            item.put("modelName", m.getMppName());
            item.put("model", m.getMppModelName());
            item.put("provider", p.getOrDefault("provider", "other"));
            item.put("modelTypes", p.getOrDefault("modelTypes", Collections.singletonList("text")));
            item.put("apiUrl", m.getMppApiUrl());
            item.put("apiKey", maskKey(m.getMppApiKey()));
            item.put("unitPrice", p.getOrDefault("unitPrice", 0));
            item.put("timeout", p.getOrDefault("timeout", 3000));
            item.put("maxConcurrency", p.getOrDefault("maxConcurrency", 10));
            item.put("temperature", p.getOrDefault("temperature", 0.7));
            item.put("maxTokens", p.getOrDefault("maxTokens", 4096));
            item.put("lastTestAt", p.get("lastTestAt"));
            item.put("lastTestOk", p.get("lastTestOk"));
            item.put("lastTestMsg", p.get("lastTestMsg"));
            item.put("status", m.getMppStatus());
            result.add(item);
        }

        return getDataTable(result);
    }

    @PreAuthorize("@ss.hasPermi('ai:model:query')")
    @GetMapping("/{modelId}")
    public AjaxResult getInfo(@PathVariable Long modelId) {
        ModelProvider m = modelProviderService.selectModelProviderByMppId(modelId);
        if (m == null) {
            return error("模型不存在");
        }
        Map<String, Object> p = parseParams(m.getMppParamsJson());
        Map<String, Object> result = new HashMap<>();
        result.put("modelId", m.getMppId());
        result.put("modelName", m.getMppName());
        result.put("model", m.getMppModelName());
        result.put("provider", p.getOrDefault("provider", "other"));
        result.put("modelTypes", p.getOrDefault("modelTypes", Collections.singletonList("text")));
        result.put("apiUrl", m.getMppApiUrl());
        // 回显脱敏 key，前端留空表示不修改
        result.put("apiKey", maskKey(m.getMppApiKey()));
        result.put("unitPrice", p.getOrDefault("unitPrice", 0));
        result.put("timeout", p.getOrDefault("timeout", 3000));
        result.put("maxConcurrency", p.getOrDefault("maxConcurrency", 10));
        result.put("temperature", p.getOrDefault("temperature", 0.7));
        result.put("maxTokens", p.getOrDefault("maxTokens", 4096));
        result.put("lastTestAt", p.get("lastTestAt"));
        result.put("lastTestOk", p.get("lastTestOk"));
        result.put("lastTestMsg", p.get("lastTestMsg"));
        result.put("status", m.getMppStatus());
        return success(result);
    }

    /** 将表单扩展字段组装进 paramsJson */
    private String buildParamsJson(Map<String, Object> body) {
        ObjectNode node = objectMapper.createObjectNode();
        putText(node, body, "provider");
        node.set("modelTypes", objectMapper.valueToTree(body.getOrDefault("modelTypes", Collections.singletonList("text"))));
        putNum(node, body, "unitPrice");
        putNum(node, body, "timeout");
        putNum(node, body, "maxConcurrency");
        putNum(node, body, "temperature");
        putNum(node, body, "maxTokens");
        return node.toString();
    }

    /** 编辑：在原 paramsJson 上合并提交字段，保留未传参数与测试留痕 */
    private String mergeParams(ModelProvider exist, Map<String, Object> body) {
        ObjectNode node;
        try {
            if (exist.getMppParamsJson() != null && !exist.getMppParamsJson().isEmpty()) {
                node = (ObjectNode) objectMapper.readTree(exist.getMppParamsJson());
            } else {
                node = objectMapper.createObjectNode();
            }
        } catch (Exception e) {
            node = objectMapper.createObjectNode();
        }
        if (body.containsKey("provider")) putText(node, body, "provider");
        if (body.containsKey("modelTypes")) {
            node.set("modelTypes", objectMapper.valueToTree(body.get("modelTypes")));
        }
        putNum(node, body, "unitPrice");
        putNum(node, body, "timeout");
        putNum(node, body, "maxConcurrency");
        putNum(node, body, "temperature");
        putNum(node, body, "maxTokens");
        return node.toString();
    }

    private void putText(ObjectNode node, Map<String, Object> body, String key) {
        Object v = body.get(key);
        if (v != null && !v.toString().isEmpty()) node.put(key, v.toString());
    }

    private void putNum(ObjectNode node, Map<String, Object> body, String key) {
        Object v = body.get(key);
        if (v instanceof Number) node.put(key, ((Number) v).doubleValue());
        else if (v != null && !v.toString().isEmpty()) {
            try { node.put(key, Double.parseDouble(v.toString())); } catch (Exception ignored) {}
        }
    }

    @PreAuthorize("@ss.hasPermi('ai:model:add')")
    @PostMapping
    @SuppressWarnings("unchecked")
    public AjaxResult add(@RequestBody Map<String, Object> body) {
        ModelProvider m = new ModelProvider();
        m.setMppName(str(body, "modelName"));
        m.setMppModelName(str(body, "model"));
        m.setMppApiUrl(str(body, "apiUrl"));
        m.setMppApiKey(encryptKey(str(body, "apiKey")));
        m.setMppParamsJson(buildParamsJson(body));
        Object status = body.get("status");
        m.setMppStatus(status == null ? 0 : Integer.valueOf(status.toString()));
        return toAjax(modelProviderService.insertModelProvider(m));
    }

    @PreAuthorize("@ss.hasPermi('ai:model:edit')")
    @PutMapping
    @SuppressWarnings("unchecked")
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Long modelId = body.get("modelId") == null ? null : Long.valueOf(body.get("modelId").toString());
        ModelProvider exist = modelProviderService.selectModelProviderByMppId(modelId);
        if (exist == null) {
            return error("模型不存在");
        }
        ModelProvider m = new ModelProvider();
        m.setMppId(modelId);
        if (body.containsKey("modelName")) m.setMppName(str(body, "modelName"));
        if (body.containsKey("model")) m.setMppModelName(str(body, "model"));
        if (body.containsKey("apiUrl")) m.setMppApiUrl(str(body, "apiUrl"));
        // apiKey 留空（脱敏值或空）时保留原 key，不清空；新值加密后落库
        String apiKey = str(body, "apiKey");
        if (apiKey != null && !apiKey.isEmpty() && !apiKey.contains("****")) {
            m.setMppApiKey(encryptKey(apiKey));
        }
        m.setMppParamsJson(mergeParams(exist, body));
        if (body.get("status") != null) m.setMppStatus(Integer.valueOf(body.get("status").toString()));
        return toAjax(modelProviderService.updateModelProvider(m));
    }

    @PreAuthorize("@ss.hasPermi('ai:model:remove')")
    @Transactional(rollbackFor = Exception.class)
    @DeleteMapping("/{modelIds}")
    public AjaxResult remove(@PathVariable Long[] modelIds) {
        for (Long id : modelIds) {
            modelProviderService.deleteModelProviderByMppId(id);
        }
        return success();
    }

    @PreAuthorize("@ss.hasPermi('ai:model:edit')")
    @PutMapping("/changeStatus")
    public AjaxResult changeStatus(@RequestBody Map<String, Object> data) {
        Object modelIdObj = data.get("modelId");
        if (modelIdObj == null) {
            return AjaxResult.error("模型ID不能为空");
        }
        Object statusObj = data.get("status");
        if (statusObj == null) {
            return AjaxResult.error("状态不能为空");
        }
        ModelProvider model = new ModelProvider();
        model.setMppId(((Number) modelIdObj).longValue());
        model.setMppStatus(Integer.valueOf(statusObj.toString()));
        return toAjax(modelProviderService.updateModelProvider(model));
    }

    @PreAuthorize("@ss.hasPermi('ai:model:list')")
    @GetMapping("/stats")
    public AjaxResult stats() {
        List<ModelProvider> all = modelProviderService.selectModelProviderList(new ModelProvider());
        int total = all.size(), enabled = 0, disabled = 0;
        for (ModelProvider m : all) {
            if (m.getMppStatus() != null && m.getMppStatus() == 0) enabled++;
            else disabled++;
        }
        Map<String, Object> out = new HashMap<>();
        out.put("total", total);
        out.put("enabled", enabled);
        out.put("disabled", disabled);
        return success(out);
    }

    @PreAuthorize("@ss.hasPermi('ai:model:edit')")
    @PostMapping("/test")
    public AjaxResult test(@RequestBody Map<String, Object> data) {
        // 支持 modelId（读库）或表单临时值（apiUrl/apiKey/model）
        String apiUrl = str(data, "apiUrl");
        String apiKey = str(data, "apiKey");
        String model = str(data, "model");
        Object modelIdObj = data.get("modelId");
        ModelProvider exist = null;
        if (modelIdObj != null) {
            exist = modelProviderService.selectModelProviderByMppId(Long.valueOf(modelIdObj.toString()));
            if (exist != null) {
                if (apiUrl == null) apiUrl = exist.getMppApiUrl();
                if (apiKey == null) apiKey = decryptKey(exist.getMppApiKey());
                if (model == null) model = exist.getMppModelName();
            }
        }
        if (apiUrl == null || apiUrl.isEmpty()) {
            return error("API地址不能为空");
        }
        String protocol;
        try {
            URI uri = URI.create(apiUrl);
            protocol = uri.getScheme();
            String host = uri.getHost();
            if (host == null || isBlockedHost(host)) {
                return error("地址不允许指向本机或内网");
            }
        } catch (Exception e) {
            return error("API地址格式非法");
        }
        if (!"https".equalsIgnoreCase(protocol) && !"http".equalsIgnoreCase(protocol)) {
            return error("只允许 http/https 协议");
        }
        if (apiKey == null || apiKey.isEmpty()) {
            return error("API Key不能为空");
        }

        long start = System.currentTimeMillis();
        Map<String, Object> out = new HashMap<>();
        HttpURLConnection conn = null;
        try {
            // OpenAI 兼容最小对话请求，用于真实校验鉴权
            Map<String, Object> chatBody = new HashMap<>();
            chatBody.put("model", model != null ? model : "gpt-3.5-turbo");
            Map<String, Object> msg = new HashMap<>();
            msg.put("role", "user");
            msg.put("content", "ping");
            chatBody.put("messages", Collections.singletonList(msg));
            chatBody.put("max_tokens", 1);
            String payload = objectMapper.writeValueAsString(chatBody);
            conn = (HttpURLConnection) new java.net.URL(apiUrl).openConnection();
            conn.setRequestMethod("POST");
            conn.setConnectTimeout(5000);
            conn.setReadTimeout(10000);
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("Authorization", "Bearer " + apiKey);
            conn.getOutputStream().write(payload.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            int code = conn.getResponseCode();
            long latency = System.currentTimeMillis() - start;
            out.put("latency", latency);
            out.put("httpCode", code);
            if (code >= 200 && code < 300) {
                out.put("success", true);
                out.put("message", "连接成功，鉴权通过，响应 " + latency + "ms");
                recordTest(exist, true, "连接成功，响应 " + latency + "ms");
                return success(out);
            }
            String reason = readError(conn, code);
            String failMsg = describe(code) + "：" + reason;
            out.put("success", false);
            out.put("message", failMsg);
            recordTest(exist, false, failMsg);
            return AjaxResult.error(failMsg);
        } catch (Exception e) {
            String failMsg = "连接失败：" + e.getMessage();
            out.put("success", false);
            out.put("message", failMsg);
            recordTest(exist, false, failMsg);
            return AjaxResult.error(failMsg);
        } finally {
            if (conn != null) conn.disconnect();
        }
    }

    private String describe(int code) {
        if (code == 401 || code == 403) return "鉴权失败，API Key 无效或无权限";
        if (code == 404) return "接口地址或模型不存在";
        if (code == 429) return "触发限流或余额不足";
        if (code >= 500) return "服务端错误 " + code;
        return "HTTP " + code;
    }

    private String readError(HttpURLConnection conn, int code) {
        try (java.io.InputStream is = code >= 400 ? conn.getErrorStream() : conn.getInputStream()) {
            if (is == null) return "";
            byte[] buf = is.readAllBytes();
            String s = new String(buf, java.nio.charset.StandardCharsets.UTF_8);
            return s.length() > 200 ? s.substring(0, 200) : s;
        } catch (Exception e) {
            return "";
        }
    }

    /** SSRF：拒绝本机、回环、私网与链路本地地址（字面匹配，避免 DNS 绕过） */
    private boolean isBlockedHost(String host) {
        String h = host.toLowerCase().trim();
        if (h.equals("localhost") || h.equals("0.0.0.0") || h.equals("::1") || h.startsWith("[")) {
            return true;
        }
        if (h.startsWith("127.") || h.startsWith("10.") || h.startsWith("192.168.")
                || h.startsWith("169.254.") || h.equals("0:0:0:0:0:0:0:1")) {
            return true;
        }
        if (h.startsWith("172.")) {
            String[] seg = h.split("\\.");
            if (seg.length >= 2) {
                int second;
                try { second = Integer.parseInt(seg[1]); } catch (Exception e) { return true; }
                if (second >= 16 && second <= 31) return true;
            }
        }
        return false;
    }

    /** 测试结果写回 paramsJson 留痕（仅对已保存模型，保留原有字段） */
    private void recordTest(ModelProvider exist, boolean ok, String message) {
        if (exist == null) return;
        try {
            ObjectNode node;
            if (exist.getMppParamsJson() != null && !exist.getMppParamsJson().isEmpty()) {
                node = (ObjectNode) objectMapper.readTree(exist.getMppParamsJson());
            } else {
                node = objectMapper.createObjectNode();
            }
            node.put("lastTestOk", ok);
            node.put("lastTestMsg", message == null ? "" : message.substring(0, Math.min(message.length(), 200)));
            node.put("lastTestAt", new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date()));
            ModelProvider upd = new ModelProvider();
            upd.setMppId(exist.getMppId());
            upd.setMppParamsJson(node.toString());
            modelProviderService.updateModelProvider(upd);
        } catch (Exception ignored) {
        }
    }

    private String str(Map<String, Object> body, String key) {
        Object v = body.get(key);
        return v == null ? null : v.toString();
    }
}
