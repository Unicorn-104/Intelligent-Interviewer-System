package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import com.ruoyi.enterprise.mapper.TalStatusMapper;

/** 终态守卫回归：已淘汰(3)/已录用(4)之后，任何业务入口都不得再推进候选人状态。 */
class TalStatusServiceTest
{
    private TalStatusService service;
    private TalStatusMapper mapper;

    private static final Long TAL_ID = 11L;
    private static final Long POSITION_ID = 22L;

    @BeforeEach
    void setup()
    {
        mapper = mock(TalStatusMapper.class);
        service = new TalStatusService(mapper);
    }

    @Test
    void rejectedCandidateCannotBeScreenedAgain()
    {
        assertTerminalBlocks(TalStatusService.TAL_REJECTED, TalStatusService.TAL_SCREENED, List.of(0, 1));
    }

    @Test
    void rejectedCandidateCannotBeRescheduledForInterview()
    {
        assertTerminalBlocks(TalStatusService.TAL_REJECTED, TalStatusService.TAL_INTERVIEWING, List.of(0, 1, 2, 7));
    }

    @Test
    void rejectedCandidateCannotBeReviewedAgain()
    {
        assertTerminalBlocks(TalStatusService.TAL_REJECTED, TalStatusService.TAL_REJECTED, List.of(2));
    }

    @Test
    void rejectedCandidateCannotTakeExam()
    {
        assertTerminalBlocks(TalStatusService.TAL_REJECTED, TalStatusService.TAL_EXAM_TAKING,
                List.of(0, 1, 2, 5, 6, 7, 8, 9));
    }

    @Test
    void offeredCandidateCannotBeRejected()
    {
        assertTerminalBlocks(TalStatusService.TAL_OFFERED, TalStatusService.TAL_REJECTED, List.of(2));
    }

    @Test
    void reapplyExplicitlyAllowsResetFromTerminalStatus()
    {
        // 转投递是“终态不可翻案”的唯一例外：显式重建投递时允许从 3/4 重置为 0，并写日志
        when(mapper.lockTalStatus(TAL_ID)).thenReturn(TalStatusService.TAL_REJECTED);
        when(mapper.updateTalStatus(TAL_ID, TalStatusService.TAL_REJECTED, TalStatusService.TAL_NEW, null, 0))
                .thenReturn(1);
        assertTrue(service.change(TAL_ID, TalStatusService.TAL_NEW, List.of(0, 1, 2, 3, 4, 5, 6, 7, 8, 9),
                POSITION_ID, 0, "转投递重置状态", 1L));
        verify(mapper).insertStatusLog(TAL_ID, TalStatusService.TAL_REJECTED, TalStatusService.TAL_NEW,
                "转投递重置状态", 1L);
        verify(mapper, never()).updateProcessInstanceStatus(eq(TAL_ID), anyLong(), any(), anyInt());
    }

    @Test
    void statusOutsideAllowedFromIsRejected()
    {
        when(mapper.lockTalStatus(TAL_ID)).thenReturn(TalStatusService.TAL_EXAM_PASSED);
        assertFalse(service.change(TAL_ID, TalStatusService.TAL_EXAM_TAKING, List.of(5), POSITION_ID,
                null, "开始笔试", 1L));
        verify(mapper, never()).updateTalStatus(anyLong(), anyInt(), anyInt(), any(), any());
        verify(mapper, never()).insertStatusLog(anyLong(), any(), anyInt(), any(), any());
    }

    @Test
    void activeCandidateAdvancesWithLogAndTerminatesInstance()
    {
        when(mapper.lockTalStatus(TAL_ID)).thenReturn(TalStatusService.TAL_INTERVIEWING);
        when(mapper.updateTalStatus(TAL_ID, TalStatusService.TAL_INTERVIEWING, TalStatusService.TAL_REJECTED,
                null, 2)).thenReturn(1);
        assertTrue(service.change(TAL_ID, TalStatusService.TAL_REJECTED, List.of(2), POSITION_ID,
                2, "面试未通过", 1L));
        verify(mapper).insertStatusLog(TAL_ID, TalStatusService.TAL_INTERVIEWING, TalStatusService.TAL_REJECTED,
                "面试未通过", 1L);
        verify(mapper).updateProcessInstanceStatus(TAL_ID, POSITION_ID, List.of(0), 3);
    }

    @Test
    void sameStatusIsIdempotentAndKeepsInstance()
    {
        when(mapper.lockTalStatus(TAL_ID)).thenReturn(TalStatusService.TAL_REJECTED);
        assertTrue(service.change(TAL_ID, TalStatusService.TAL_REJECTED, List.of(3), POSITION_ID,
                (Integer) null, "重复驳回", 1L));
        verify(mapper, never()).updateTalStatus(anyLong(), anyInt(), anyInt(), any(), any());
        verify(mapper, never()).insertStatusLog(anyLong(), any(), anyInt(), any(), any());
    }

    private void assertTerminalBlocks(int currentStatus, int toStatus, List<Integer> allowedFrom)
    {
        when(mapper.lockTalStatus(TAL_ID)).thenReturn(currentStatus);
        assertFalse(service.change(TAL_ID, toStatus, allowedFrom, POSITION_ID, 2, "终态不可变更", 1L));
        verify(mapper, never()).updateTalStatus(anyLong(), anyInt(), anyInt(), any(), any());
        verify(mapper, never()).insertStatusLog(anyLong(), any(), anyInt(), any(), any());
        verify(mapper, never()).updateProcessInstanceStatus(eq(TAL_ID), anyLong(), any(), anyInt());
    }
}
