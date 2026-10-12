package com.ruoyi.system.service.impl;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.mapper.ConferenceMapper;
import com.ruoyi.system.service.IConferenceSignalService;

/**
 * 面试视频会议 WebRTC 信令通道实现（SSE + Redis 一次性票据）
 *
 * 说明：在线注册表为单机内存 Map，当前单实例部署可用；
 * 若水平扩展需改为 Redis pub/sub 转发。
 *
 * @author ruoyi
 */
@Service
public class ConferenceSignalServiceImpl implements IConferenceSignalService
{
    /** 票据缓存前缀 */
    private static final String TICKET_KEY = "conference:signal:ticket:";
    /** 票据反向索引前缀（同一用户重复签发时使旧票立即失效） */
    private static final String USER_TICKET_KEY = "conference:signal:user:";
    /** 票据有效期（秒） */
    private static final int TICKET_TTL = 7200;
    /** 允许转发的信令类型 */
    private static final Set<String> SIGNAL_TYPES = new HashSet<>(Arrays.asList("offer", "answer", "ice", "ready", "bye"));
    /** 心跳间隔（秒），注释帧防止代理缓冲与空闲断流 */
    private static final int HEARTBEAT_SECONDS = 20;

    /** sessionId -> userId -> emitter（当前在线信令通道） */
    private final ConcurrentHashMap<Long, ConcurrentHashMap<Long, SseEmitter>> rooms = new ConcurrentHashMap<>();

    private ScheduledExecutorService heartbeatExecutor;

    @Autowired
    private ConferenceMapper conferenceMapper;

    @Autowired
    private RedisCache redisCache;

    @PostConstruct
    public void startHeartbeat()
    {
        heartbeatExecutor = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "conference-signal-hb");
            t.setDaemon(true);
            return t;
        });
        heartbeatExecutor.scheduleWithFixedDelay(this::sendHeartbeat, HEARTBEAT_SECONDS, HEARTBEAT_SECONDS, TimeUnit.SECONDS);
    }

    @PreDestroy
    public void stopHeartbeat()
    {
        if (heartbeatExecutor != null)
        {
            heartbeatExecutor.shutdownNow();
        }
        rooms.values().forEach(room -> room.values().forEach(emitter -> emitter.complete()));
        rooms.clear();
    }

    @Override
    public Map<String, Object> issueTicket(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = conferenceMapper.selectSessionContext(sessionId);
        if (ctx == null || ctx.isEmpty())
        {
            throw new ServiceException("面试场次不存在");
        }
        Long candidateUserId = toLong(ctx.get("candidateUserId"));
        String role = resolveRole(ctx, sessionId, userId);
        if (role == null)
        {
            throw new ServiceException("无权访问该面试场次");
        }
        String ticket = UUID.randomUUID().toString().replace("-", "");

        // 同一用户重复签发：删除旧票，使其立即失效
        String userKey = USER_TICKET_KEY + sessionId + ":" + userId;
        Object oldTicket = redisCache.getCacheObject(userKey);
        if (oldTicket != null)
        {
            redisCache.deleteObject(TICKET_KEY + oldTicket);
        }
        JSONObject info = new JSONObject();
        info.put("sessionId", sessionId);
        info.put("userId", userId);
        info.put("role", role);
        redisCache.setCacheObject(TICKET_KEY + ticket, info.toJSONString(), TICKET_TTL, TimeUnit.SECONDS);
        redisCache.setCacheObject(userKey, ticket, TICKET_TTL, TimeUnit.SECONDS);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("ticket", ticket);
        result.put("userId", userId);
        result.put("role", role);
        result.put("sessionId", sessionId);
        result.put("expiresInSeconds", TICKET_TTL);
        List<Map<String, Object>> peers = new ArrayList<>();
        ConcurrentHashMap<Long, SseEmitter> room = rooms.get(sessionId);
        if (room != null)
        {
            room.forEach((peerId, emitter) -> {
                if (!peerId.equals(userId))
                {
                    String peerRole = resolveRole(ctx, sessionId, peerId);
                    Map<String, Object> peer = new LinkedHashMap<>();
                    peer.put("userId", peerId);
                    peer.put("role", peerRole == null ? (peerId.equals(candidateUserId) ? "CANDIDATE" : "HR") : peerRole);
                    peers.add(peer);
                }
            });
        }
        result.put("peers", peers);
        return result;
    }

    /**
     * 解析用户在信令场次中的角色：CANDIDATE / HR / OBSERVER，无权限返回 null
     */
    private String resolveRole(Map<String, Object> ctx, Long sessionId, Long userId)
    {
        if (userId.equals(toLong(ctx.get("candidateUserId"))))
        {
            return "CANDIDATE";
        }
        if (userId.equals(toLong(ctx.get("interviewerId"))) || isAssignedInterviewer(sessionId, userId))
        {
            return "HR";
        }
        Long sessionCompanyId = toLong(ctx.get("companyId"));
        Long userCompanyId = conferenceMapper.selectCompanyIdByUser(userId);
        if (sessionCompanyId != null && sessionCompanyId.equals(userCompanyId))
        {
            return "OBSERVER";
        }
        return null;
    }

    /**
     * 该用户是否为场次被指派面试官（关联表）
     */
    private boolean isAssignedInterviewer(Long sessionId, Long userId)
    {
        for (Map<String, Object> item : conferenceMapper.selectSessionInterviewers(sessionId))
        {
            if (userId.equals(toLong(item.get("userId"))))
            {
                return true;
            }
        }
        return false;
    }

    @Override
    public SseEmitter openStream(String ticket)
    {
        JSONObject info = readTicket(ticket);
        Long sessionId = info.getLong("sessionId");
        Long userId = info.getLong("userId");
        String role = info.getString("role");

        SseEmitter emitter = new SseEmitter(0L);
        ConcurrentHashMap<Long, SseEmitter> room = rooms.computeIfAbsent(sessionId, k -> new ConcurrentHashMap<>());
        SseEmitter previous = room.put(userId, emitter);
        if (previous != null)
        {
            // 同一用户重连（页面刷新）：静默摘除旧通道，避免误报 peer-left
            room.remove(userId, previous);
            safeComplete(previous);
        }
        emitter.onCompletion(() -> detach(sessionId, userId, emitter));
        emitter.onTimeout(() -> detach(sessionId, userId, emitter));
        emitter.onError(e -> detach(sessionId, userId, emitter));

        pushTo(sessionId, userId, emitter, userId, role, "self-joined", new LinkedHashMap<>());
        broadcast(sessionId, userId, role, "peer-joined", new LinkedHashMap<>());
        return emitter;
    }

    @Override
    public void relay(String ticket, String type, Map<String, Object> payload, Long toUserId)
    {
        if (StringUtils.isEmpty(type) || !SIGNAL_TYPES.contains(type))
        {
            throw new ServiceException("不支持的信令类型");
        }
        JSONObject info = readTicket(ticket);
        Long sessionId = info.getLong("sessionId");
        Long fromUserId = info.getLong("userId");
        String fromRole = info.getString("role");
        // 多方网状：offer / answer / ice 必须定向到目标端，否则会串到其他面试官的连接上；
        // 未指定目标时（如 bye）仍按广播处理，兼容两人场景
        if (toUserId != null && !toUserId.equals(fromUserId))
        {
            ConcurrentHashMap<Long, SseEmitter> room = rooms.get(sessionId);
            SseEmitter target = room == null ? null : room.get(toUserId);
            if (target != null)
            {
                pushTo(sessionId, toUserId, target, fromUserId, fromRole, type, payload);
            }
            return;
        }
        broadcast(sessionId, fromUserId, fromRole, type, payload);
    }

    /**
     * 读取并校验票据
     */
    private JSONObject readTicket(String ticket)
    {
        if (StringUtils.isEmpty(ticket))
        {
            throw new ServiceException("缺少信令票据");
        }
        Object cached = redisCache.getCacheObject(TICKET_KEY + ticket);
        if (cached == null)
        {
            throw new ServiceException("信令票据无效或已过期，请重新进入会议");
        }
        return JSON.parseObject(cached.toString());
    }

    /**
     * 转发给同场次除发送者外的全部在线端
     */
    private void broadcast(Long sessionId, Long fromUserId, String fromRole, String type, Map<String, Object> payload)
    {
        ConcurrentHashMap<Long, SseEmitter> room = rooms.get(sessionId);
        if (room == null)
        {
            return;
        }
        room.forEach((peerId, emitter) -> {
            if (!peerId.equals(fromUserId))
            {
                pushTo(sessionId, peerId, emitter, fromUserId, fromRole, type, payload);
            }
        });
    }

    /**
     * 向单个通道发送 signal 事件；失败即在锁外摘除该通道并通知对端离开。
     * 摘除动作放在 synchronized 之外，避免互发失败时两把 emitter 锁交叉死锁。
     */
    private void pushTo(Long sessionId, Long targetUserId, SseEmitter emitter, Long fromUserId, String fromRole, String type, Map<String, Object> payload)
    {
        Map<String, Object> event = new LinkedHashMap<>();
        event.put("from", fromUserId);
        event.put("fromRole", fromRole);
        event.put("type", type);
        event.put("payload", payload == null ? new LinkedHashMap<String, Object>() : payload);
        boolean sent;
        synchronized (emitter)
        {
            try
            {
                emitter.send(SseEmitter.event().name("signal").data(JSON.toJSONString(event)));
                sent = true;
            }
            catch (IOException | IllegalStateException e)
            {
                sent = false;
            }
        }
        if (!sent)
        {
            detach(sessionId, targetUserId, emitter);
        }
    }

    /**
     * 心跳注释帧（EventSource 自动忽略，但足以让中间代理持续 flush）
     */
    private void sendHeartbeat()
    {
        rooms.forEach((sessionId, room) -> room.forEach((userId, emitter) -> {
            boolean sent;
            synchronized (emitter)
            {
                try
                {
                    emitter.send(SseEmitter.event().comment("hb"));
                    sent = true;
                }
                catch (IOException | IllegalStateException e)
                {
                    sent = false;
                }
            }
            if (!sent)
            {
                detach(sessionId, userId, emitter);
            }
        }));
    }

    /**
     * 通道关闭回调：仅当 Map 中仍是本通道时摘除，并通知对端离开
     */
    private void detach(Long sessionId, Long userId, SseEmitter emitter)
    {
        ConcurrentHashMap<Long, SseEmitter> room = rooms.get(sessionId);
        if (room == null || !room.remove(userId, emitter))
        {
            return;
        }
        Map<String, Object> leftPayload = new LinkedHashMap<>();
        leftPayload.put("userId", userId);
        room.forEach((peerId, peerEmitter) -> pushTo(sessionId, peerId, peerEmitter, userId, "", "peer-left", leftPayload));
    }

    private void safeComplete(SseEmitter emitter)
    {
        try
        {
            emitter.complete();
        }
        catch (Exception ignored)
        {
            // 旧通道可能已断开，忽略
        }
    }

    private Long toLong(Object value)
    {
        if (value == null)
        {
            return null;
        }
        if (value instanceof Number)
        {
            return ((Number) value).longValue();
        }
        try
        {
            return Long.parseLong(value.toString());
        }
        catch (NumberFormatException e)
        {
            return null;
        }
    }
}
