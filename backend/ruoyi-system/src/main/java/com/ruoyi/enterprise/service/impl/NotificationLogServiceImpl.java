package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.NotificationLogMapper;
import com.ruoyi.enterprise.service.INotificationLogService;

/**
 * 企业端 - 通知发送日志与统计服务实现
 *
 * <p>依据《业务功能分析》UC-16 E2：
 * 检索通知发送记录，统计送达率、打开率、点击率。</p>
 * <p>存储说明：t_msg 记录系统通知消息（含已读标记 msg_is_read/msg_read_at，
 * 可作为邮件打开率的近似口径）；渠道送达回执与链接点击埋点暂无存储列，
 * 对应指标字段返回 null，待 P7 对接渠道回调后补充。</p>
 *
 * @author enterprise
 */
@Service
public class NotificationLogServiceImpl implements INotificationLogService
{
    @Autowired
    private NotificationLogMapper notificationLogMapper;

    @Override
    public List<Map<String, Object>> listLogs(Long userId, String candidate, String scene,
            String from, String to, Integer pageNum, Integer pageSize)
    {
        PageUtils.startPage(pageNum, pageSize);
        // scene 对应消息类型（msg_type），类型枚举口径 P7 与通知模板模块对齐
        return notificationLogMapper.selectLogs(candidate, scene, from, to);
    }

    @Override
    public Map<String, Object> getStats(Long userId)
    {
        Map<String, Object> base = notificationLogMapper.selectStatsBase();
        long total = base == null || base.get("total") == null ? 0
                : Long.parseLong(String.valueOf(base.get("total")));
        long read = base == null || base.get("read") == null ? 0
                : Long.parseLong(String.valueOf(base.get("read")));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("totalSent", total);
        result.put("openCount", read);
        result.put("openRate", total == 0 ? 0 : round(read * 100.0 / total));
        // 送达率/点击率依赖渠道回执与点击埋点存储，P7 对接后补充
        result.put("deliveryRate", null);
        result.put("clickRate", null);
        return result;
    }

    private double round(double value)
    {
        return BigDecimal.valueOf(value).setScale(1, RoundingMode.HALF_UP).doubleValue();
    }
}
