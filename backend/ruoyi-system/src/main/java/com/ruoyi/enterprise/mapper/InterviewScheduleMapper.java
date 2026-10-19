package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/** 企业端面试预约、阶段排期和忙闲查询。 */
public interface InterviewScheduleMapper
{
    List<Map<String, Object>> selectAppointments(@Param("companyId") Long companyId,
            @Param("status") Integer status, @Param("from") String from, @Param("to") String to);
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
    List<Map<String, Object>> selectConflicts(@Param("candidateId") Long candidateId,
            @Param("interviewerId") Long interviewerId, @Param("startTime") String startTime,
            @Param("endTime") String endTime, @Param("excludeAppointmentId") Long excludeAppointmentId,
            @Param("excludeSlotId") Long excludeSlotId);
    int updateSlotStatus(@Param("slotId") Long slotId, @Param("status") Integer status);
    int insertSlot(Map<String, Object> values);
    int insertAppointment(Map<String, Object> values);
    int updateAppointmentTime(Map<String, Object> values);
    int updateAppointmentStatus(@Param("appointmentId") Long appointmentId, @Param("status") Integer status);
    int markCandidateInterviewing(@Param("candidateId") Long candidateId);
    int insertReminderMessage(@Param("receiverId") Long receiverId, @Param("title") String title,
            @Param("content") String content);
}
