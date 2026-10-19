package com.ruoyi.system.service;

import java.util.Map;

/**
 * LiveKit 视频会议 Access Token 签发服务
 * 
 * @author YLX
 */
public interface ILiveKitTokenService
{
    /**
     * 为指定场次签发 LiveKit 入会令牌（含场次参与权限校验）
     * 
     * @param userId 当前登录用户
     * @param sessionId 面试场次ID
     * @return url / token / room / identity
     */
    public Map<String, Object> issueToken(Long userId, Long sessionId);
}
