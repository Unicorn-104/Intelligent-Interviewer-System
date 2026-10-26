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

    /** 清空指定时间范围内当前面试官的空闲时段（整周覆盖保存） */
    int deleteSlots(@Param("interviewerId") Long interviewerId, @Param("from") String from,
            @Param("to") String to);

    /** 批量写入空闲时段 */
    int insertSlots(@Param("interviewerId") Long interviewerId, @Param("slots") List<Map<String, Object>> slots);
}
