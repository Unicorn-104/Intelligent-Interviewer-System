package com.ruoyi.system.service;

import java.util.Map;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * 面试视频会议 WebRTC 信令通道（SSE）
 *
 * @author ruoyi
 */
public interface IConferenceSignalService
{
    /**
     * 签发一次性信令票据（需 JWT 认证后调用）
     *
     * @return {ticket, role, peers:[{userId, role}]}
     */
    public Map<String, Object> issueTicket(Long userId, Long sessionId);

    /**
     * 校验票据并注册 SSE 通道；注册成功向本人推 roster、向对端推 peer-joined
     */
    public SseEmitter openStream(String ticket);

    /**
     * 校验票据并把 {type, payload} 转发给同场次对端
     *
     * @param type offer | answer | ice | ready | bye
     * @param toUserId 目标端；仅转发给该用户（多方网状定向信令），为空则广播
     */
    public void relay(String ticket, String type, Map<String, Object> payload, Long toUserId);
}
