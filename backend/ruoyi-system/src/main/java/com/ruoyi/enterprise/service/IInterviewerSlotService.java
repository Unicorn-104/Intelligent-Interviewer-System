package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 面试官空闲时段服务
 */
public interface IInterviewerSlotService
{
    /**
     * 查询当前登录面试官某周的空闲时段
     *
     * @param userId 当前登录用户
     * @param weekStart 周一日期 yyyy-MM-dd，为空时取本周
     */
    public List<Map<String, Object>> listSlots(Long userId, String weekStart);

    /**
     * 整周覆盖保存空闲时段（先删后插）
     *
     * @param userId 当前登录用户
     * @param weekStart 周一日期 yyyy-MM-dd
     * @param slots 时段列表（startTime/endTime 为 yyyy-MM-dd HH:mm:ss）
     */
    public Map<String, Object> saveSlots(Long userId, String weekStart, List<Map<String, Object>> slots);
}
