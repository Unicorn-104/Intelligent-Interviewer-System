package com.ruoyi.system.service.app;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.app.AppJobMapper;
import com.ruoyi.system.service.IEnterpriseJobService;
import com.ruoyi.system.service.app.impl.AppJobServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** 投递后必须同步创建流程实例，企业端岗位详情/漏斗/筛选才能看到新求职者。 */
@ExtendWith(MockitoExtension.class)
class AppJobApplyProcessTest
{
    @Mock private AppJobMapper jobMapper;
    @Mock private IEnterpriseJobService enterpriseJobService;
    @InjectMocks private AppJobServiceImpl service;

    @BeforeEach
    void applyBasics()
    {
        lenient().when(jobMapper.selectDefaultResumeId(104L)).thenReturn(7L);
        lenient().when(jobMapper.selectCompanyIdByPositionId(39L)).thenReturn(2L);
        lenient().when(jobMapper.selectCandidateId(104L, 2L)).thenReturn(null, 5L);
        lenient().when(jobMapper.insertCandidate(104L, 2L, 7L)).thenReturn(1);
        lenient().when(jobMapper.countApplication(5L, 39L)).thenReturn(0);
        lenient().when(jobMapper.insertApplication(5L, 39L, 7L)).thenReturn(1);
    }

    @Test
    void applyCreatesProcessInstanceAfterApplication()
    {
        service.apply(104L, 39L);
        var order = inOrder(jobMapper, enterpriseJobService);
        order.verify(jobMapper).insertApplication(5L, 39L, 7L);
        order.verify(enterpriseJobService).ensureProcessInstance(2L, 5L, 39L);
    }

    @Test
    void existingCandidateStillGetsProcessInstance()
    {
        when(jobMapper.selectCandidateId(104L, 2L)).thenReturn(5L);
        service.apply(104L, 39L);
        verify(jobMapper, never()).insertCandidate(anyLong(), anyLong(), anyLong());
        verify(enterpriseJobService).ensureProcessInstance(2L, 5L, 39L);
    }

    @Test
    void processInstanceFailureFailsTheApplication()
    {
        when(jobMapper.selectCandidateId(104L, 2L)).thenReturn(5L);
        when(enterpriseJobService.ensureProcessInstance(2L, 5L, 39L))
                .thenThrow(new ServiceException("投递流程实例创建失败，请稍后重试"));
        assertThrows(ServiceException.class, () -> service.apply(104L, 39L));
    }

    @Test
    void keepsExistingRejectionsForDuplicateApplications()
    {
        when(jobMapper.selectCandidateId(104L, 2L)).thenReturn(5L);
        when(jobMapper.countApplication(5L, 39L)).thenReturn(1);
        assertThrows(ServiceException.class, () -> service.apply(104L, 39L));
        verify(jobMapper, never()).insertApplication(anyLong(), anyLong(), anyLong());
        verifyNoInteractions(enterpriseJobService);
    }
}
