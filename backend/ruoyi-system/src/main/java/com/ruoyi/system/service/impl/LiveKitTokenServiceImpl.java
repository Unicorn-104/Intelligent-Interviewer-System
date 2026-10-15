package com.ruoyi.system.service.impl;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.service.IConferenceService;
import com.ruoyi.system.service.ILiveKitTokenService;

/**
 * LiveKit 视频会议 Access Token 签发服务
 * <p>
 * 按 LiveKit Access Token 协议生成 HS256 JWT（iss/sub/exp + video 授权声明），
 * 仅用 JDK 加签，不引入 livekit server SDK。入会前复用
 * {@link IConferenceService#getSessionContext} 完成场次参与权限校验。
 *
 * @author YLX
 */
@Service
public class LiveKitTokenServiceImpl implements ILiveKitTokenService
{
    @Value("${livekit.api-key:}")
    private String apiKey;

    @Value("${livekit.api-secret:}")
    private String apiSecret;

    /** 客户端连接地址（企业端/候选人端共用） */
    @Value("${livekit.url:ws://localhost:7880}")
    private String livekitUrl;

    /** 令牌有效期（秒） */
    @Value("${livekit.token-ttl-seconds:7200}")
    private long ttlSeconds;

    @Autowired
    private IConferenceService conferenceService;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public Map<String, Object> issueToken(Long userId, Long sessionId)
    {
        if (StringUtils.isEmpty(apiKey) || StringUtils.isEmpty(apiSecret))
        {
            throw new ServiceException("LiveKit 服务未配置（livekit.api-key / livekit.api-secret）");
        }
        // 复用既有场次上下文校验：非参与人（面试官/关联面试官/候选人）直接抛无权访问
        Map<String, Object> ctx = conferenceService.getSessionContext(userId, sessionId);

        Object roomId = ctx.get("roomId");
        String room = (roomId == null || StringUtils.isEmpty(String.valueOf(roomId)))
                ? "INTERVIEW-" + sessionId : String.valueOf(roomId);
        String identity = "u" + userId;

        // 观察者（OBSERVER）仅入会旁听，禁止发布音视频/数据；候选人/面试官可正常发布
        String role = ctx.get("role") == null ? null : String.valueOf(ctx.get("role"));
        boolean canPublish = !"OBSERVER".equals(role);

        long now = System.currentTimeMillis() / 1000L;
        Map<String, Object> video = new LinkedHashMap<>();
        video.put("kind", "participant");
        video.put("room", room);
        video.put("roomJoin", true);
        video.put("canPublish", canPublish);
        video.put("canSubscribe", true);
        video.put("canPublishData", canPublish);

        Map<String, Object> claims = new LinkedHashMap<>();
        claims.put("iss", apiKey);
        claims.put("sub", identity);
        claims.put("nbf", now - 10);
        claims.put("exp", now + ttlSeconds);
        claims.put("video", video);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("url", livekitUrl);
        result.put("token", signHs256(claims));
        result.put("room", room);
        result.put("identity", identity);
        return result;
    }

    /** 生成 LiveKit Access Token（header.payload.signature，Base64URL 无填充） */
    private String signHs256(Map<String, Object> claims)
    {
        try
        {
            Map<String, Object> header = new LinkedHashMap<>();
            header.put("alg", "HS256");
            header.put("typ", "JWT");
            Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
            String signingInput = encoder.encodeToString(objectMapper.writeValueAsBytes(header))
                    + "." + encoder.encodeToString(objectMapper.writeValueAsBytes(claims));
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(apiSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] signature = mac.doFinal(signingInput.getBytes(StandardCharsets.US_ASCII));
            return signingInput + "." + encoder.encodeToString(signature);
        }
        catch (Exception e)
        {
            throw new ServiceException("签发 LiveKit 令牌失败：" + e.getMessage());
        }
    }
}
