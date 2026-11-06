package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/** 企业端面试预约、阶段排期和忙闲查询。 */
public interface InterviewScheduleMapper
{
    List<Map<String, Object>> selectAppointments(@Param("companyId") Long companyId,
            @Param("status") Integer status, @Param("from") String from, @Param("to") String to,
            @Param("candidateId") Long candidateId);
    Map<String, Object> selectStageByIdForPosition(@Param("stageId") Long stageId,
            @Param("positionId") Long positionId);
    Map<String, Object> selectAppointmentById(@Param("appointmentId") Long appointmentId);
    List<Map<String, Object>> selectCandidateAppointments(@Param("candidateId") Long candidateId,
            @Param("positionId") Long positionId);
    List<Map<String, Object>> selectSlots(@Param("interviewerId") Long interviewerId,
            @Param("from") String from, @Param("to") String to);
    Long lockCandidate(@Param("candidateId") Long candidateId);
    Long lockInterviewer(@Param("interviewerId") Long interviewerId);
    int countInterviewerInCompany(@Param("interviewerId") Long interviewerId, @Param("companyId") Long companyId);
    int countApplication(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId);
    int countSchedulableApplication(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId);
    /** 岗位流程中排在目标阶段之前、类型为笔试(1) 的阶段数量 */
    int countExamStagesBefore(@Param("positionId") Long positionId, @Param("stageOrder") Integer stageOrder);
    List<Map<String, Object>> selectConflicts(@Param("candidateId") Long candidateId,
            @Param("interviewerId") Long interviewerId, @Param("startTime") String startTime,
            @Param("endTime") String endTime, @Param("excludeAppointmentId") Long excludeAppointmentId,
            @Param("excludeSlotId") Long excludeSlotId);
    int updateSlotStatus(@Param("slotId") Long slotId, @Param("status") Integer status);
    int insertSlot(Map<String, Object> values);
    int insertAppointment(Map<String, Object> values);
    int updateAppointmentTime(Map<String, Object> values);
    int updateAppointmentStatus(@Param("appointmentId") Long appointmentId, @Param("status") Integer status);
    /** 显式重置提醒状态：只重置已处理(1)的标记，不影响发送中(2)的认领 */
    int resetAppointmentRemindFlag(@Param("appointmentId") Long appointmentId);
    int markCandidateInterviewing(@Param("candidateId") Long candidateId);
    int insertReminderMessage(@Param("receiverId") Long receiverId, @Param("title") String title,
            @Param("content") String content);
    /** 预约行锁：取消前与改期申请审批保持同一锁顺序（候选人 → 预约）。 */
    Long lockAppointment(@Param("appointmentId") Long appointmentId);
    /** 该候选人在该岗位除指定预约外的有效预约数（0/1 待确认、已确认），决定投递状态是否回退。 */
    int countOtherValidAppointments(@Param("candidateId") Long candidateId,
            @Param("positionId") Long positionId, @Param("excludeAppointmentId") Long excludeAppointmentId);
}
