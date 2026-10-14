package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - 通知发送日志与统计服务层
 *
 * <p>依据《业务功能分析》UC-16 E2（HR 查看发送日志与统计指标）。</p>
 *
 * @author enterprise
 */
public interface INotificationLogService
{
    /**
     * 发送日志检索（UC-16 E2）：候选人/场景/时间范围 + 分页
     */
    public List<Map<String, Object>> listLogs(Long userId, String candidate, String scene,
            String from, String to, Integer pageNum, Integer pageSize);

    /**
     * 通知统计（UC-16 E2）：总量/打开率（基于 msg_is_read 计算）；
     * 送达率/点击率依赖渠道回执与链接点击埋点（暂无存储列），接入后补充
     */
    public Map<String, Object> getStats(Long userId);
}
