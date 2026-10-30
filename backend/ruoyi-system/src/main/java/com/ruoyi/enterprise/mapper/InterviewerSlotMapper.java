package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 面试官空闲时段（t_sch_slot）
 */
public interface InterviewerSlotMapper
{
    /** 指定时间范围内当前面试官的空闲时段 */
    List<Map<String, Object>> selectSlots(@Param("interviewerId") Long interviewerId,
            @Param("from") String from, @Param("to") String to);

    /**
     * 清空指定时间范围内未被有效预约引用的时段（整周覆盖保存）。
     * 被待确认/已确认预约（apt_status 0/1）引用的占用时段必须保留，
     * 仅凭时段状态值不能判断是否可删，需检查预约引用。
     */
    int deleteUnreferencedSlots(@Param("interviewerId") Long interviewerId, @Param("from") String from,
            @Param("to") String to);

    /** 与待确认/已确认面试（apt_status 0/1）时间重叠的场次列表（保存可用时段前的冲突检查） */
    List<Map<String, Object>> selectConflictingAppointments(@Param("interviewerId") Long interviewerId,
            @Param("startTime") String startTime, @Param("endTime") String endTime);

    /** 面试官行锁：与预约创建/改期的面试官锁串行化，防止并发保存时段与并发预约互相破坏 */
    Long lockInterviewer(@Param("interviewerId") Long interviewerId);

    /** 批量写入空闲时段 */
    int insertSlots(@Param("interviewerId") Long interviewerId, @Param("slots") List<Map<String, Object>> slots);
}
