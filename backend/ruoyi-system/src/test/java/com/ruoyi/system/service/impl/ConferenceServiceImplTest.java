package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.sql.Timestamp;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.ApplicationStatusService;
import com.ruoyi.enterprise.service.TalStatusService;
import com.ruoyi.system.event.InterviewSessionCreatedEvent;
import com.ruoyi.system.mapper.ConferenceMapper;

/**
 * 发起视频面试（createRoomLink）：有效预约互斥、时间窗口校验与纯AI 自动出题事件。
 */
public class ConferenceServiceImplTest
{
    private ConferenceServiceImpl service;
    private ConferenceMapper conferenceMapper;
    private ApplicationEventPublisher eventPublisher;
    private TalStatusService talStatusService;

    @BeforeEach
    void setUp()
    {
        conferenceMapper = mock(ConferenceMapper.class);
        eventPublisher = mock(ApplicationEventPublisher.class);
        talStatusService = mock(TalStatusService.class);
        when(talStatusService.change(anyLong(), anyInt(), anyList(), anyLong(), any(), any(), anyLong()))
                .thenReturn(true);
        service = new ConferenceServiceImpl();
        ReflectionTestUtils.setField(service, "conferenceMapper", conferenceMapper);
        ReflectionTestUtils.setField(service, "eventPublisher", eventPublisher);
        ReflectionTestUtils.setField(service, "screeningMapper", mock(ScreeningMapper.class));
        ReflectionTestUtils.setField(service, "applicationStatusMapper", mock(ApplicationStatusMapper.class));
        ReflectionTestUtils.setField(service, "applicationStatusService", mock(ApplicationStatusService.class));
        ReflectionTestUtils.setField(service, "talStatusService", talStatusService);
    }

    /** 发起基础桩：HR(5) 发起、候选人(11)、岗位(7)、公司(2)、面试官(19)。 */
    private void stubRelaunchBasics()
    {
        when(conferenceMapper.selectCompanyIdByUser(5L)).thenReturn(2L);
        when(conferenceMapper.selectTalentByUserId(11L, 2L)).thenReturn(Map.of("candidateId", 11L));
        when(conferenceMapper.selectPositionCompanyId(7L)).thenReturn(2L);
        when(conferenceMapper.countSchedulableApplication(11L, 7L)).thenReturn(1);
        when(conferenceMapper.selectCompanyEmployees(anyMap())).thenReturn(List.of(Map.of("userId", 19L)));
        when(conferenceMapper.lockCandidateForUpdate(11L)).thenReturn(11L);
        // Mockito 对 Map 返回值默认返回空 Map，这里显式声明「没有有效预约」
        when(conferenceMapper.selectActiveAppointment(11L, 7L, 2L)).thenReturn(null);
        when(conferenceMapper.insertAppointment(anyMap())).thenAnswer(invocation ->
        {
            ((Map<String, Object>) invocation.getArgument(0)).put("appointmentId", 201L);
            return 1;
        });
        when(conferenceMapper.insertSession(anyMap())).thenAnswer(invocation ->
        {
            ((Map<String, Object>) invocation.getArgument(0)).put("sessionId", 301L);
            return 1;
        });
        when(conferenceMapper.selectSessionContext(301L)).thenReturn(new LinkedHashMap<>(Map.of(
                "companyName", "合成企业", "positionTitle", "合成岗位", "candidateName", "合成候选人",
                "appointmentStartAt", "2026-10-30 10:00", "appointmentEndAt", "2026-10-30 10:45",
                "durationMinutes", 45, "mode", 2, "status", 0)));
        when(conferenceMapper.selectSessionInterviewers(301L)).thenReturn(List.of());
    }

    @Test
    void activeAppointmentBlocksNewLaunch()
    {
        stubRelaunchBasics();
        Map<String, Object> active = new LinkedHashMap<>();
        active.put("appointmentId", 101L);
        active.put("positionTitle", "合成岗位");
        active.put("startTime", "2026-10-30 10:00");
        when(conferenceMapper.selectActiveAppointment(11L, 7L, 2L)).thenReturn(active);

        assertThrows(ServiceException.class,
                () -> service.createRoomLink(5L, 11L, 7L, null, 45, 2, List.of(19L), null));
        verify(conferenceMapper, never()).insertAppointment(anyMap());
    }

    @Test
    void pureAiSessionPublishesOutlineGenerationEvent()
    {
        stubRelaunchBasics();

        var result = service.createRoomLink(5L, 11L, 7L, null, 45, 1, List.of(), null);

        assertEquals(301L, ((Number) result.get("sessionId")).longValue());
        ArgumentCaptor<InterviewSessionCreatedEvent> captor =
                ArgumentCaptor.forClass(InterviewSessionCreatedEvent.class);
        verify(eventPublisher).publishEvent(captor.capture());
        assertEquals(301L, captor.getValue().getSessionId().longValue());
    }

    @Test
    void humanModeDoesNotPublishOutlineGenerationEvent()
    {
        stubRelaunchBasics();

        service.createRoomLink(5L, 11L, 7L, null, 45, 2, List.of(19L), null);

        verify(eventPublisher, never()).publishEvent(any(InterviewSessionCreatedEvent.class));
    }

    @Test
    void explicitStartTimeBuildsAppointmentWindow()
    {
        stubRelaunchBasics();

        service.createRoomLink(5L, 11L, 7L, null, 45, null, List.of(19L), "2099-01-01 09:00");

        ArgumentCaptor<Map<String, Object>> captor = ArgumentCaptor.forClass(Map.class);
        verify(conferenceMapper).insertAppointment(captor.capture());
        assertEquals(Timestamp.valueOf("2099-01-01 09:00:00"), captor.getValue().get("startTime"));
        assertEquals(Timestamp.valueOf("2099-01-01 09:45:00"), captor.getValue().get("endTime"));
    }

    @Test
    void pastStartTimeIsRejected()
    {
        stubRelaunchBasics();

        assertThrows(ServiceException.class,
                () -> service.createRoomLink(5L, 11L, 7L, null, 45, null, List.of(19L), "2020-01-01 09:00"));
        verify(conferenceMapper, never()).insertAppointment(anyMap());
    }
}
