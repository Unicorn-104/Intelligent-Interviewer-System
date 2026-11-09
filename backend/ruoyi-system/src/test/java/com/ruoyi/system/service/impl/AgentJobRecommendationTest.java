package com.ruoyi.system.service.impl;

import com.github.pagehelper.PageHelper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.mapper.agent.AgentJobMapper;
import com.ruoyi.system.service.impl.agent.AgentJobServiceImpl;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AgentJobRecommendationTest
{
    private final AgentJobMapper mapper = mock(AgentJobMapper.class);
    private final AgentJobServiceImpl service = new AgentJobServiceImpl();

    AgentJobRecommendationTest()
    {
        ReflectionTestUtils.setField(service, "jobMapper", mapper);
    }

    @AfterEach
    void clearPagination()
    {
        PageHelper.clearPage();
    }

    @Test
    void rejectsUnavailableResumeBeforeStartingPaginationOrQueryingJobs()
    {
        AgentJobQuery query = new AgentJobQuery();
        query.setResumeId(20L);
        assertThrows(ServiceException.class, () -> service.selectJobs(query, 100L));
        verify(mapper).countAvailableResume(20L, 100L);
        verify(mapper, never()).selectJobList(any(), any());
        assertNull(PageHelper.getLocalPage());
    }

    @Test
    void ownedResumeIsPassedUnchangedAndOmissionKeepsLegacyBehavior()
    {
        AgentJobQuery query = new AgentJobQuery();
        query.setResumeId(12L);
        when(mapper.countAvailableResume(12L, 100L)).thenReturn(1);
        when(mapper.selectJobList(any(), eq(100L))).thenReturn(java.util.List.of());
        service.selectJobs(query, 100L);
        verify(mapper).selectJobList(query, 100L);
        assertEquals(12L, query.getResumeId());
        PageHelper.clearPage();
        clearInvocations(mapper);
        service.selectJobs(new AgentJobQuery(), 100L);
        verify(mapper, never()).countAvailableResume(any(), any());
    }
}
