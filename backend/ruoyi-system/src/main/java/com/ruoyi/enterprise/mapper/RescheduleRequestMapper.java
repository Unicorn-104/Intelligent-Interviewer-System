package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

public interface RescheduleRequestMapper
{
    List<Map<String, Object>> selectCompanyRequests(@Param("companyId") Long companyId,
            @Param("status") Integer status);
    List<Map<String, Object>> selectOwnRequests(@Param("userId") Long userId);
    Map<String, Object> selectRequest(@Param("requestId") Long requestId,
            @Param("companyId") Long companyId);
    Map<String, Object> lockRequest(@Param("requestId") Long requestId,
            @Param("companyId") Long companyId);
    Map<String, Object> selectAppointment(@Param("appointmentId") Long appointmentId);
    Long lockAppointment(@Param("appointmentId") Long appointmentId);
    int countPending(@Param("appointmentId") Long appointmentId);
    int insertRequest(Map<String, Object> request);
    List<Long> selectCompanyUserIds(@Param("companyId") Long companyId);
    int insertNotification(@Param("receiverId") Long receiverId, @Param("title") String title,
            @Param("content") String content, @Param("targetUrl") String targetUrl);

    int updateDecision(@Param("requestId") Long requestId, @Param("companyId") Long companyId,
            @Param("status") int status, @Param("reviewerId") Long reviewerId,
            @Param("reviewNote") String reviewNote);
}
