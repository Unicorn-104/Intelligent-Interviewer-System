package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 智能预约调度数据层
 *
 * <p>依据《业务功能分析》UC-07/08/09：
 * 面试官可用时段 t_sch_slot（0-已占用，1-可用）、
 * 预约记录 t_sch_appointment（0-待确认，1-已确认，2-已取消，3-已完成）、
 * 提醒消息 t_msg。</p>
 *
 * @author enterprise
 */
public interface InterviewScheduleMapper
{
    /** 预约列表（含候选人/岗位/面试官信息） */
    public List<Map<String, Object>> selectAppointments(@Param("status") Integer status,
            @Param("from") String from, @Param("to") String to);

    /** 预约详情 */
    public Map<String, Object> selectAppointmentById(@Param("appointmentId") Long appointmentId);

    /** 面试官时段列表（忙闲，UC-08） */
    public List<Map<String, Object>> selectSlots(@Param("interviewerId") Long interviewerId,
            @Param("from") String from, @Param("to") String to);

    /** 与指定时间重叠的已占用时段（冲突检测） */
    public List<Map<String, Object>> selectOverlapOccupied(@Param("interviewerId") Long interviewerId,
            @Param("startTime") String startTime, @Param("endTime") String endTime);

    /** 精确匹配的可用时段（存在则占用） */
    public Long selectAvailableSlot(@Param("interviewerId") Long interviewerId,
            @Param("startTime") String startTime, @Param("endTime") String endTime);

    /** 更新时段状态（占用/释放） */
    public int updateSlotStatus(@Param("slotId") Long slotId, @Param("status") Integer status);

    /** 新建时段（无精确匹配时按需创建） */
    public int insertSlot(@Param("interviewerId") Long interviewerId, @Param("positionId") Long positionId,
            @Param("startTime") String startTime, @Param("endTime") String endTime,
            @Param("status") Integer status);

    /** 查询刚创建的时段ID */
    public Long selectLastInsertSlot(@Param("interviewerId") Long interviewerId, @Param("startTime") String startTime);

    /** 创建预约记录 */
    public int insertAppointment(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId,
            @Param("interviewerId") Long interviewerId, @Param("slotId") Long slotId,
            @Param("startTime") String startTime, @Param("endTime") String endTime,
            @Param("meetingUrl") String meetingUrl);

    /** 查询刚创建的预约ID */
    public Long selectLastAppointment(@Param("candidateId") Long candidateId);

    /** 更新预约时间（改期） */
    public int updateAppointmentTime(@Param("appointmentId") Long appointmentId, @Param("slotId") Long slotId,
            @Param("startTime") String startTime, @Param("endTime") String endTime);

    /** 向候选人写入提醒消息 */
    public int insertReminderMessage(@Param("receiverId") Long receiverId, @Param("title") String title,
            @Param("content") String content);
}
