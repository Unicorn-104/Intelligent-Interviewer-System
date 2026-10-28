package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.enterprise.mapper.EnterpriseJdMapper;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;

/** jobDetail 打开岗位时须为缺实例的历史投递补建流程实例，保证漏斗与候选人列表非空。 */
class EnterpriseJobDetailRepairTest
{
    private final EnterpriseJobMapper jobs = mock(EnterpriseJobMapper.class);
    private final EnterpriseJobServiceImpl service = new EnterpriseJobServiceImpl();

    @BeforeEach
    void setup()
    {
        DashboardMapper dashboard = mock(DashboardMapper.class);
        when(dashboard.selectCompanyIdByUser(17L)).thenReturn(7L);
        ReflectionTestUtils.setField(service, "jobMapper", jobs);
        ReflectionTestUtils.setField(service, "dashboardMapper", dashboard);
        ReflectionTestUtils.setField(service, "jdMapper", mock(EnterpriseJdMapper.class));
    }

    @Test
    void missingInstanceApplicationIsRepairedBeforeReadingFunnelAndCandidates()
    {
        when(jobs.selectJobById(1L, 7L)).thenReturn(Map.of("posId", 1L, "templateId", 9L));
        when(jobs.selectApplicationsMissingInstance(1L)).thenReturn(List.of(Map.of("applicationId", 45L, "candidateId", 17L)));
        when(jobs.selectJobForUpdate(1L, 7L)).thenReturn(Map.of("posId", 1L, "templateId", 9L));
        when(jobs.selectProcessInstance(17L, 1L)).thenReturn(null);
        when(jobs.selectFirstStageIdByPosition(1L)).thenReturn(61L);
        when(jobs.insertProcessInstance(anyMap())).thenAnswer(invocation ->
        {
            Map<String, Object> params = invocation.getArgument(0);
            params.put("pinId", 100L);
            return 1;
        });

        Map<String, Object> result = service.jobDetail(17L, 1L);

        verify(jobs).insertProcessInstance(argThat(params -> 17L == ((Number) params.get("candidateId")).longValue()
                && 1L == ((Number) params.get("positionId")).longValue()
                && 9L == ((Number) params.get("templateId")).longValue()
                && 61L == ((Number) params.get("stageId")).longValue()));
        verify(jobs).updateApplicationInstance(17L, 1L, 100L);
        verify(jobs).updateTalentInstanceIfAbsent(17L, 100L);
        verify(jobs).selectJobFunnel(1L);
        verify(jobs).selectJobCandidates(1L);
        assertNotNull(result.get("funnel"));
        assertNotNull(result.get("candidates"));
    }

    @Test
    void existingInstanceIsNotDuplicatedAndRepairFailureDoesNotBlockDetail()
    {
        when(jobs.selectJobById(1L, 7L)).thenReturn(Map.of("posId", 1L, "templateId", 9L));
        when(jobs.selectApplicationsMissingInstance(1L)).thenReturn(List.of(Map.of("applicationId", 45L, "candidateId", 17L)));
        when(jobs.selectJobForUpdate(1L, 7L)).thenReturn(Map.of("posId", 1L, "templateId", 9L));
        when(jobs.selectProcessInstance(17L, 1L)).thenReturn(Map.of("pinId", 100L));

        service.jobDetail(17L, 1L);

        verify(jobs, never()).insertProcessInstance(anyMap());
        verify(jobs).selectJobCandidates(1L);
    }

    @Test
    void repairFailureIsLoggedAndDetailStillReturns()
    {
        when(jobs.selectJobById(1L, 7L)).thenReturn(Map.of("posId", 1L, "templateId", 9L));
        when(jobs.selectApplicationsMissingInstance(1L)).thenReturn(List.of(Map.of("applicationId", 45L, "candidateId", 17L)));
        when(jobs.selectJobForUpdate(1L, 7L)).thenReturn(null); // 岗位行锁失败模拟

        Map<String, Object> result = service.jobDetail(17L, 1L);

        assertNotNull(result.get("funnel"));
        assertNotNull(result.get("candidates"));
    }
}
