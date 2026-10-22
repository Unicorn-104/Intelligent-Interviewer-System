package com.ruoyi.system.asr;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.TreeMap;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.apache.commons.lang3.StringUtils;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.system.config.AsrProperties;

/**
 * 腾讯云实时语音识别 WebSocket 实现。
 */
@Component
@ConditionalOnProperty(prefix = "app.asr", name = "provider", havingValue = "tencent", matchIfMissing = true)
public class TencentAsrProvider implements AsrProvider
{
    private static final String NAME = "tencent";

    private final AsrProperties properties;

    public TencentAsrProvider(AsrProperties properties)
    {
        this.properties = properties;
    }

    @Override
    public String name()
    {
        return NAME;
    }

    @Override
    public boolean isConfigured()
    {
        return properties.isReady();
    }

    @Override
    public URI buildStreamUri(AsrStreamContext context)
    {
        AsrProperties.Tencent cfg = properties.getTencent();
        long timestamp = System.currentTimeMillis() / 1000L;
        long expired = timestamp + Math.max(60, cfg.getExpireSeconds());

        TreeMap<String, String> params = new TreeMap<>();
        params.put("engine_model_type", cfg.getEngineModelType());
        params.put("expired", String.valueOf(expired));
        params.put("needvad", "1");
        params.put("nonce", String.valueOf(ThreadLocalRandom.current().nextInt(100000, 999999999)));
        params.put("secretid", cfg.getSecretId());
        params.put("timestamp", String.valueOf(timestamp));
        params.put("vad_silence_time", String.valueOf(cfg.getVadSilenceTime()));
        params.put("voice_format", "1");
        params.put("voice_id", buildVoiceId(context));

        String query = params.entrySet().stream()
                .map(entry -> entry.getKey() + "=" + urlEncode(entry.getValue()))
                .collect(Collectors.joining("&"));

        URI base = URI.create(cfg.getWsBaseUrl());
        String path = base.getPath();
        if (!path.endsWith("/"))
        {
            path = path + "/";
        }
        path = path + cfg.getAppId();
        String signOrigin = base.getHost() + path + "?" + query;
        String signature = sign(signOrigin, cfg.getSecretKey());
        String url = base.getScheme() + "://" + base.getHost()
                + (base.getPort() > 0 ? ":" + base.getPort() : "")
                + path + "?" + query + "&signature=" + urlEncode(signature);
        return URI.create(url);
    }

    @Override
    public AsrEvent parse(String message)
    {
        if (StringUtils.isBlank(message))
        {
            return AsrEvent.none();
        }
        JSONObject root = JSON.parseObject(message);
        if (root == null)
        {
            return AsrEvent.none();
        }
        int code = root.getIntValue("code", 0);
        if (code != 0)
        {
            String msg = root.getString("message");
            return AsrEvent.error(StringUtils.isNotBlank(msg) ? msg : "语音识别服务返回错误码 " + code);
        }
        JSONObject result = root.getJSONObject("result");
        if (result == null)
        {
            return AsrEvent.none();
        }
        String text = result.getString("voice_text_str");
        if (StringUtils.isBlank(text))
        {
            return AsrEvent.none();
        }
        // slice_type=2 表示一句话结束，结果已稳定
        if (result.getIntValue("slice_type", 0) == 2)
        {
            return AsrEvent.finalText(text.trim());
        }
        return AsrEvent.none();
    }

    private String buildVoiceId(AsrStreamContext context)
    {
        String role = context.getRole() == null ? "user" : context.getRole().toLowerCase();
        return "s" + context.getSessionId() + "_" + role + "_" + UUID.randomUUID().toString().replace("-", "");
    }

    private String sign(String origin, String secretKey)
    {
        try
        {
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec(secretKey.getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
            byte[] digest = mac.doFinal(origin.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        }
        catch (Exception e)
        {
            throw new IllegalStateException("生成语音识别签名失败", e);
        }
    }

    private String urlEncode(String value)
    {
        return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
    }
}
