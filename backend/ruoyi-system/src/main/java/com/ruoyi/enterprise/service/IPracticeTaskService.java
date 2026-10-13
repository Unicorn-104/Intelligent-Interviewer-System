package com.ruoyi.enterprise.service;

import java.util.Map;

/**
 * 企业端 - 在线实操环境预加载服务层
 *
 * <p>依据《业务功能分析》UC-11（在线实操环境预加载）。</p>
 *
 * @author enterprise
 */
public interface IPracticeTaskService
{
    /**
     * 预加载实操环境（UC-11）：校验场次与实操任务就绪状态
     */
    public Map<String, Object> preload(Long userId, Long sessionId);

    /**
     * 预加载状态查询（UC-11）：场次 + 实操任务清单 + 就绪状态
     */
    public Map<String, Object> status(Long userId, Long sessionId);
}
