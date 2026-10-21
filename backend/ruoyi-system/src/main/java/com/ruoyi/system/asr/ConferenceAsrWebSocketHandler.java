package com.ruoyi.system.asr;

import java.io.IOException;
import java.net.URI;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.BinaryMessage;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.AbstractWebSocketHandler;
import org.springframework.web.util.UriComponentsBuilder;

import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.system.config.AsrProperties;
import com.ruoyi.system.service.IConferenceService;

/**
 * 实时字幕 WebSocket 代理端点。
 *
 * 前端只连接本服务，腾讯云密钥与签名均不出后端；音频帧在此转发，
 * 稳定句由服务端直接落库，另一端通过字幕增量接口获取。
 */
@Component
public class ConferenceAsrWebSocketHandler extends AbstractWebSocketHandler
{
    private static final Logger log = LoggerFactory.getLogger(ConferenceAsrWebSocketHandler.class);

    private static final String ATTR_CONNECTION = "conference.asr.connection";

    private static final int MAX_AUDIO_FRAME_BYTES = 12800;

    private final RedisCache redisCache;

    private final IConferenceService conferenceService;

    private final AsrProperties asrProperties;

    private final List<AsrProvider> providers;

    public ConferenceAsrWebSocketHandler(RedisCache redisCache, IConferenceService conferenceService,
            AsrProperties asrProperties, List<AsrProvider> providers)
    {
        this.redisCache = redisCache;
        this.conferenceService = conferenceService;
        this.asrProperties = asrProperties;
        this.providers = providers;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception
    {
        String ticket = queryParam(session.getUri(), "ticket");
        if (ticket == null)
        {
            close(session, CloseStatus.POLICY_VIOLATION);
            return;
        }
        Object cached = redisCache.redisTemplate.opsForValue()
                .getAndDelete(IConferenceService.ASR_TICKET_CACHE_PREFIX + ticket);
        if (!(cached instanceof String))
        {
            log.warn("实时字幕连接被拒绝: 票据无效或已使用");
            close(session, CloseStatus.POLICY_VIOLATION);
            return;
        }
        JSONObject payload = JSON.parseObject((String) cached);
        Long sessionId = payload == null ? null : payload.getLong("sessionId");
        Long userId = payload == null ? null : payload.getLong("userId");
        String role = payload == null ? null : payload.getString("role");
        if (sessionId == null || userId == null || role == null)
        {
            close(session, CloseStatus.POLICY_VIOLATION);
            return;
        }

        // 票据使用前再次校验：仅 AI 面试且面试未结束时允许建立识别流
        Map<String, Object> status;
        try
        {
            status = conferenceService.getAsrStatus(userId, sessionId);
        }
        catch (RuntimeException e)
        {
            send(session, message("error", e.getMessage()));
            close(session, CloseStatus.POLICY_VIOLATION);
            return;
        }
        if (!Boolean.TRUE.equals(status.get("enabled")))
        {
            send(session, message("error", status.get("reason")));
            close(session, CloseStatus.POLICY_VIOLATION);
            return;
        }

        AsrProvider provider = resolveProvider();
        if (provider == null)
        {
            send(session, message("error", asrProperties.getUnavailableReason()));
            close(session, CloseStatus.POLICY_VIOLATION);
            return;
        }

        URI uri = provider.buildStreamUri(new AsrStreamContext(sessionId, role));
        int dlgRole = "HR".equals(role) ? 2 : 3;
        TencentAsrConnection connection = new TencentAsrConnection(uri, provider,
                text -> {
                    int sequence = conferenceService.appendAsrCaption(sessionId, role, text);
                    if (sequence <= 0)
                    {
                        return;
                    }
                    Map<String, Object> payloadMap = message("final", text);
                    payloadMap.put("sequence", sequence);
                    payloadMap.put("role", dlgRole);
                    send(session, payloadMap);
                },
                error -> {
                    send(session, message("error", error));
                    close(session, CloseStatus.SERVER_ERROR);
                });
        session.getAttributes().put(ATTR_CONNECTION, connection);
        connection.connect();
        send(session, message("ready", null));
        log.info("实时字幕连接建立: sessionId={} role={}", sessionId, role);
    }

    @Override
    protected void handleBinaryMessage(WebSocketSession session, BinaryMessage message) throws Exception
    {
        TencentAsrConnection connection = (TencentAsrConnection) session.getAttributes().get(ATTR_CONNECTION);
        if (connection == null)
        {
            return;
        }
        ByteBuffer buffer = message.getPayload();
        int size = buffer.remaining();
        if (size <= 0 || size > MAX_AUDIO_FRAME_BYTES)
        {
            close(session, CloseStatus.TOO_BIG_TO_PROCESS);
            return;
        }
        byte[] audio = new byte[size];
        buffer.get(audio);
        connection.sendAudio(audio);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception
    {
        TencentAsrConnection connection = (TencentAsrConnection) session.getAttributes().get(ATTR_CONNECTION);
        if (connection == null)
        {
            return;
        }
        String payload = message.getPayload();
        if (payload != null && payload.contains("\"end\""))
        {
            // 结束帧后仍需等待识别服务返回尾句，WebSocket 由前端主动关闭
            connection.end();
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception
    {
        TencentAsrConnection connection = (TencentAsrConnection) session.getAttributes().remove(ATTR_CONNECTION);
        if (connection != null)
        {
            connection.end();
        }
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) throws Exception
    {
        TencentAsrConnection connection = (TencentAsrConnection) session.getAttributes().remove(ATTR_CONNECTION);
        if (connection != null)
        {
            connection.abort();
        }
        close(session, CloseStatus.SERVER_ERROR);
    }

    private AsrProvider resolveProvider()
    {
        if (providers == null || providers.isEmpty())
        {
            return null;
        }
        for (AsrProvider provider : providers)
        {
            if (provider.name().equalsIgnoreCase(asrProperties.getProvider()) && provider.isConfigured())
            {
                return provider;
            }
        }
        return null;
    }

    private String queryParam(URI uri, String name)
    {
        if (uri == null)
        {
            return null;
        }
        return UriComponentsBuilder.fromUri(uri).build().getQueryParams().getFirst(name);
    }

    private Map<String, Object> message(String type, Object content)
    {
        Map<String, Object> payload = new HashMap<>();
        payload.put("type", type);
        if ("final".equals(type))
        {
            payload.put("content", content);
        }
        else if (content != null)
        {
            payload.put("message", content);
        }
        return payload;
    }

    private void send(WebSocketSession session, Map<String, Object> payload)
    {
        if (session == null || !session.isOpen())
        {
            return;
        }
        try
        {
            synchronized (session)
            {
                session.sendMessage(new TextMessage(JSON.toJSONString(payload)));
            }
        }
        catch (IOException e)
        {
            log.debug("实时字幕消息发送失败: {}", e.getMessage());
        }
    }

    private void close(WebSocketSession session, CloseStatus status)
    {
        try
        {
            if (session != null && session.isOpen())
            {
                session.close(status);
            }
        }
        catch (IOException e)
        {
            log.debug("实时字幕连接关闭失败: {}", e.getMessage());
        }
    }
}
