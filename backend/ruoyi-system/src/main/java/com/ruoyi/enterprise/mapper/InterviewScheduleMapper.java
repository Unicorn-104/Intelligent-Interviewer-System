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
    /** 该候选人跨所有岗位除指定预约外的有效预约数，决定候选人状态是否回退。 */
    int countValidAppointmentsExcluding(@Param("candidateId") Long candidateId,
            @Param("excludeAppointmentId") Long excludeAppointmentId);
    /** 该岗位下已完成面试场次数（含其他阶段），用于防止把已完成阶段的候选人回退。 */
    int countCompletedSessions(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId);
    /** 招聘流程实例状态（0-进行中，1-已完成，2-已终止，3-已淘汰）。 */
    Integer selectProcessInstanceStatus(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId);
    /** 候选人当前流程状态。 */
    Integer selectTalStatus(@Param("candidateId") Long candidateId);
    /** 该岗位当前投递状态。 */
    Integer selectApplicationStatus(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId);
    /** 最近一次进入「面试中(2)」之前的流程状态（由 t_tal 状态触发器记录）。 */
    Integer selectPriorTalStatus(@Param("candidateId") Long candidateId);
    /** 仅当候选人仍处于「面试中(2)」时恢复为取消预约前的流程状态，避免覆盖并发变更。 */
    int restoreTalStatus(@Param("candidateId") Long candidateId, @Param("status") Integer status);
    /** 仅当投递仍处于「已约面(3)」时恢复，与候选人状态保持同源。 */
    int restoreApplicationStatus(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId,
            @Param("status") Integer status);
}
