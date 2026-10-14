package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 通知发送日志数据层
 *
 * <p>依据《业务功能分析》UC-16 E2：
 * 系统消息表 t_msg（发送记录 + 已读状态）。</p>
 *
 * @author enterprise
 */
public interface NotificationLogMapper
{
    /** 发送日志检索（候选人/场景/时间范围） */
    public List<Map<String, Object>> selectLogs(@Param("candidate") String candidate,
            @Param("scene") String scene, @Param("from") String from, @Param("to") String to);

    /** 统计基础数据（总量/已读数） */
    public Map<String, Object> selectStatsBase();
}
