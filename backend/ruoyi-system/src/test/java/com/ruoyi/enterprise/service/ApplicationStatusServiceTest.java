package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import com.ruoyi.common.enums.ApplicationEndReason;
import com.ruoyi.common.enums.ApplicationStatus;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;

/**
 * 岗位投递状态机单元测试：用 mock 数据层验证流转守卫、终态保护、幂等、
 * 终止原因校验、并发保护与撤回，覆盖招聘状态重构的核心业务规则。
 */
class ApplicationStatusServiceTest
{
    private ApplicationStatusMapper mapper;
    private ApplicationStatusService service;
    /** 模拟数据库中当前 app_status，随守卫更新变化 */
    private int current;

    @BeforeEach
    void setup()
    {
        mapper = Mockito.mock(ApplicationStatusMapper.class);
        service = new ApplicationStatusService(mapper);
        current = 0;
        when(mapper.lockAppStatus(any())).thenAnswer(inv -> current);
        when(mapper.updateAppStatus(any(), anyInt(), anyInt())).thenAnswer(inv -> {
            int from = inv.getArgument(1), to = inv.getArgument(2);
            if (from != current) return 0;
            current = to;
            return 1;
        });
        when(mapper.selectApplicationById(any()))
                .thenReturn(Map.of("candidateId", 11L, "positionId", 7L));
        when(mapper.updateEndFields(any(), any(), any(), any())).thenReturn(1);
        when(mapper.insertStatusLog(any(), any(), any(), any(), anyInt(), any(), any(), any()))
                .thenReturn(1);
        when(mapper.updateProcessInstanceStatus(any(), any(), anyList(), anyInt())).thenReturn(1);
    }

    /** 场景六：已投递→招聘中→待发Offer→待确认Offer→已录用 */
    @Test
    void fullHiringPathFollowsLegalTransitions()
    {
        assertTrue(service.startRecruitment(1L, 3L));
        assertEquals(1, current);
        assertTrue(service.passToPendingOffer(1L, 3L));
        assertEquals(2, current);
        assertTrue(service.offerSent(1L, 3L));
        assertEquals(3, current);
        assertTrue(service.offerAccepted(1L, 3L, ApplicationStatusService.SOURCE_OFFER));
        assertEquals(4, current);
        // 每次流转一条日志，已录用收尾流程实例一次
        verify(mapper, times(4)).insertStatusLog(any(), any(), any(), any(), anyInt(), any(), any(), any());
        verify(mapper).updateProcessInstanceStatus(any(), any(), anyList(), eq(1));
    }

    /** 场景十一：终态（已录用/未录用）普通业务操作不得推进 */
    @Test
    void terminalStatesRejectFurtherTransitions()
    {
        current = 4;
        assertThrows(ServiceException.class, () -> service.startRecruitment(1L, 3L));
        current = 5;
        assertThrows(ServiceException.class, () -> service.offerSent(1L, 3L));
        verify(mapper, never()).updateAppStatus(any(), anyInt(), anyInt());
    }

    /** 非法跳变（已投递直接到已录用）被守卫拒绝 */
    @Test
    void illegalJumpIsRejected()
    {
        current = 0;
        assertThrows(ServiceException.class, () ->
                service.transition(1L, ApplicationStatus.HIRED, 3L,
                        ApplicationStatusService.SOURCE_HR, null, "x"));
        verify(mapper, never()).updateAppStatus(any(), anyInt(), anyInt());
    }

    /** 幂等：已是目标状态直接返回，不重复更新、不重复写日志 */
    @Test
    void sameTargetIsIdempotent()
    {
        current = 1;
        assertTrue(service.startRecruitment(1L, 3L));
        verify(mapper, never()).updateAppStatus(any(), anyInt(), anyInt());
        verify(mapper, never()).insertStatusLog(any(), any(), any(), any(), anyInt(), any(), any(), any());
    }

    /** 场景五：HR 主动淘汰进未录用，写终止字段并把流程实例置为终止 */
    @Test
    void hrTerminateWritesEndFieldsAndClosesProcess()
    {
        current = 1;
        assertTrue(service.terminate(1L, ApplicationEndReason.HR_REJECTED, 3L,
                ApplicationStatusService.SOURCE_HR, "HR 主动淘汰"));
        assertEquals(5, current);
        verify(mapper).updateEndFields(eq(1L), eq("HR_REJECTED"), eq(3L), eq("HR 主动淘汰"));
        verify(mapper).updateProcessInstanceStatus(any(), any(), anyList(), eq(3));
    }

    /** 未录用必须带终止原因 */
    @Test
    void terminateWithoutReasonFails()
    {
        current = 1;
        assertThrows(ServiceException.class, () ->
                service.transition(1L, ApplicationStatus.NOT_HIRED, 3L,
                        ApplicationStatusService.SOURCE_HR, null, "x"));
        verify(mapper, never()).updateAppStatus(any(), anyInt(), anyInt());
    }

    /** HR 淘汰必须记录操作人 */
    @Test
    void hrRejectWithoutOperatorFails()
    {
        current = 1;
        assertThrows(ServiceException.class, () ->
                service.terminate(1L, ApplicationEndReason.HR_REJECTED, null,
                        ApplicationStatusService.SOURCE_HR, "x"));
    }

    /** 终止原因只能在未录用时填写，其他状态带原因报错 */
    @Test
    void reasonOnNonNotHiredFails()
    {
        current = 0;
        assertThrows(ServiceException.class, () ->
                service.transition(1L, ApplicationStatus.IN_PROGRESS, 3L,
                        ApplicationStatusService.SOURCE_HR, ApplicationEndReason.HR_REJECTED, "x"));
    }

    /** 场景九：候选人撤回进未录用，原因 CANDIDATE_WITHDRAWN，可不带 HR 操作人 */
    @Test
    void withdrawRoutesToNotHired()
    {
        when(mapper.selectAppId(11L, 7L)).thenReturn(1L);
        current = 0;
        assertTrue(service.withdraw(11L, 7L, null));
        assertEquals(5, current);
        verify(mapper).updateEndFields(eq(1L), eq("CANDIDATE_WITHDRAWN"), isNull(), any());
    }

    /** 投递记录不存在时抛错 */
    @Test
    void missingRecordFails()
    {
        when(mapper.lockAppStatus(any())).thenReturn(null);
        assertThrows(ServiceException.class, () -> service.startRecruitment(1L, 3L));
    }

    /** 并发守卫更新返回 0（状态已被他人修改）时抛错，不写日志 */
    @Test
    void concurrentUpdateZeroThrows()
    {
        current = 0;
        when(mapper.updateAppStatus(any(), anyInt(), anyInt())).thenReturn(0);
        assertThrows(ServiceException.class, () -> service.startRecruitment(1L, 3L));
        verify(mapper, never()).insertStatusLog(any(), any(), any(), any(), anyInt(), any(), any(), any());
    }
}
