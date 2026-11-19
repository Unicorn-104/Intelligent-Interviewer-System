package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.service.ApplicationStatusService;
import com.ruoyi.enterprise.service.TalStatusService;
import com.ruoyi.system.mapper.ConferenceMapper;

/** 已有面试预约点击开始时，应复用预约而不是再次创建预约。 */
class ConferenceScheduledAppointmentTest
{
    private ConferenceServiceImpl service;
    private ConferenceMapper conferenceMapper;
    private ApplicationStatusMapper applicationStatusMapper;
    private ApplicationStatusService applicationStatusService;
    private TalStatusService talStatusService;

    @BeforeEach
    void setUp()
    {
        conferenceMapper = mock(ConferenceMapper.class);
        applicationStatusMapper = mock(ApplicationStatusMapper.class);
        applicationStatusService = mock(ApplicationStatusService.class);
        talStatusService = mock(TalStatusService.class);
        service = new ConferenceServiceImpl();
        ReflectionTestUtils.setField(service, "conferenceMapper", conferenceMapper);
        ReflectionTestUtils.setField(service, "applicationStatusMapper", applicationStatusMapper);
        ReflectionTestUtils.setField(service, "applicationStatusService", applicationStatusService);
        ReflectionTestUtils.setField(service, "talStatusService", talStatusService);
        when(talStatusService.change(anyLong(), anyInt(), anyList(), anyLong(), any(), any(), anyLong()))
                .thenReturn(true);
    }

    @Test
    void startsSpecifiedAppointmentWithoutCreatingAnotherAppointment()
    {
        when(conferenceMapper.selectCompanyIdByUser(5L)).thenReturn(2L);
        when(conferenceMapper.selectTalentByUserId(11L, 2L)).thenReturn(Map.of("candidateId", 101L));
        when(conferenceMapper.selectPositionCompanyId(7L)).thenReturn(2L);
        when(conferenceMapper.countSchedulableApplication(101L, 7L)).thenReturn(1);
        when(conferenceMapper.selectCompanyEmployees(anyMap())).thenReturn(List.of(Map.of("userId", 19L)));
        when(conferenceMapper.lockCandidateForUpdate(101L)).thenReturn(101L);
        when(conferenceMapper.selectActiveAppointment(101L, 7L, 2L)).thenReturn(
                Map.of("appointmentId", 201L, "positionTitle", "示例岗位", "startTime", "2099-01-01 09:00"));
        Map<String, Object> appointment = new LinkedHashMap<>();
        appointment.put("appointmentId", 201L);
        appointment.put("interviewerId", 19L);
        appointment.put("stageOrder", 1);
        appointment.put("sessionId", null);
        appointment.put("roomId", null);
        appointment.put("roomToken", null);
        when(conferenceMapper.selectAppointmentForConference(201L, 101L, 7L, 2L)).thenReturn(appointment);
        when(conferenceMapper.insertSession(anyMap())).thenAnswer(invocation -> {
            ((Map<String, Object>) invocation.getArgument(0)).put("sessionId", 301L);
            return 1;
        });
        when(conferenceMapper.selectSessionContext(301L)).thenReturn(new LinkedHashMap<>(Map.of(
                "companyName", "示例企业", "positionTitle", "示例岗位", "candidateName", "若依",
                "appointmentStartAt", "2099-01-01 09:00", "appointmentEndAt", "2099-01-01 09:45",
                "durationMinutes", 45, "mode", 2, "status", 0)));
        when(conferenceMapper.selectSessionInterviewers(301L)).thenReturn(List.of());

        Map<String, Object> result = service.createRoomLink(5L, 11L, 7L, null, 45, 2, List.of(19L),
                "2020-01-01 09:00", 201L);

        verify(conferenceMapper, never()).insertAppointment(anyMap());
        verify(conferenceMapper).insertSession(anyMap());
        assertEquals(301L, result.get("sessionId"));
        assertFalse(String.valueOf(result.get("token")).isBlank());
    }
}
