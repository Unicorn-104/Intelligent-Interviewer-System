package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.IInterviewScheduleService;
import com.ruoyi.system.mapper.ConferenceMapper;

/**
 * 重新发起面试（createRoomLink）的统一取消链路：
 * 旧待面试预约逐个经面试调度服务的取消逻辑处理（释放时段 + 恢复状态），
 * 会议创建与投递状态推进保持原有顺序与语义。
 */
public class ConferenceServiceImplTest
{
    private ConferenceServiceImpl service;
    private ConferenceMapper conferenceMapper;
    private IInterviewScheduleService scheduleService;
    private ScreeningMapper screeningMapper;

    @BeforeEach
    void setUp()
    {
        conferenceMapper = mock(ConferenceMapper.class);
        scheduleService = mock(IInterviewScheduleService.class);
        screeningMapper = mock(ScreeningMapper.class);
        service = new ConferenceServiceImpl();
        ReflectionTestUtils.setField(service, "conferenceMapper", conferenceMapper);
        ReflectionTestUtils.setField(service, "scheduleService", scheduleService);
        ReflectionTestUtils.setField(service, "screeningMapper", screeningMapper);
    }

    /** 发起基础桩：HR(5) 发起、候选人(11)、岗位(7)、公司(2)、面试官(19)。 */
    private void stubRelaunchBasics()
    {
        when(conferenceMapper.selectCompanyIdByUser(5L)).thenReturn(2L);
        when(conferenceMapper.selectTalentByUserId(11L, 2L)).thenReturn(Map.of("candidateId", 11L));
        when(conferenceMapper.selectPositionCompanyId(7L)).thenReturn(2L);
        when(conferenceMapper.selectCompanyEmployees(anyMap())).thenReturn(List.of(Map.of("userId", 19L)));
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
    void relaunchCancelsEachPendingAppointmentViaScheduleServiceBeforeCreatingNew()
    {
        stubRelaunchBasics();
        when(conferenceMapper.selectPendingAppointmentIds(11L, 2L)).thenReturn(List.of(101L, 102L));
        when(scheduleService.cancelForRelaunch(5L, 101L)).thenReturn(Map.of("appointmentId", 101L));
        when(scheduleService.cancelForRelaunch(5L, 102L)).thenReturn(Map.of("appointmentId", 102L));

        var result = service.createRoomLink(5L, 11L, 7L, null, 45, null, List.of(19L));

        // 顺序契约：先终止旧场次 → 逐个统一取消旧预约 → 再创建新预约/场次 → 推进投递状态
        InOrder order = inOrder(conferenceMapper, scheduleService, screeningMapper);
        order.verify(conferenceMapper).abortActiveSessionsByCandidate(11L, 2L);
        order.verify(scheduleService).cancelForRelaunch(5L, 101L);
        order.verify(scheduleService).cancelForRelaunch(5L, 102L);
        order.verify(conferenceMapper).insertAppointment(anyMap());
        order.verify(screeningMapper).advanceApplicationStatus(7L, 11L, 3, List.of(0, 1, 2));
        verify(conferenceMapper).markCandidateInterviewing(11L, 2L);
        assertEquals(301L, ((Number) result.get("sessionId")).longValue());
        assertEquals("合成候选人", result.get("candidateName"));
    }

    @Test
    void relaunchWithoutPendingAppointmentsStillCreatesSessionAndAdvancesStatus()
    {
        stubRelaunchBasics();
        when(conferenceMapper.selectPendingAppointmentIds(11L, 2L)).thenReturn(List.of());

        var result = service.createRoomLink(5L, 11L, 7L, null, 45, null, List.of(19L));

        verify(scheduleService, never()).cancelForRelaunch(anyLong(), anyLong());
        verify(screeningMapper).advanceApplicationStatus(7L, 11L, 3, List.of(0, 1, 2));
        assertEquals(301L, ((Number) result.get("sessionId")).longValue());
    }

    @Test
    void relaunchIgnoresSkippedCancelResultsAndKeepsCreating()
    {
        stubRelaunchBasics();
        when(conferenceMapper.selectPendingAppointmentIds(11L, 2L)).thenReturn(List.of(101L, 102L));
        // 101 已完成/已取消被统一入口跳过；102 正常取消
        when(scheduleService.cancelForRelaunch(5L, 101L)).thenReturn(Map.of("message", "该面试安排已完成，已跳过"));
        when(scheduleService.cancelForRelaunch(5L, 102L)).thenReturn(Map.of("message", "已取消该面试安排，面试官时段已释放"));

        var result = service.createRoomLink(5L, 11L, 7L, null, 45, null, List.of(19L));

        verify(scheduleService).cancelForRelaunch(5L, 101L);
        verify(scheduleService).cancelForRelaunch(5L, 102L);
        verify(conferenceMapper).insertAppointment(anyMap());
        assertEquals(301L, ((Number) result.get("sessionId")).longValue());
    }
}
