package com.ruoyi.system.service.impl;

import com.github.pagehelper.PageHelper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.domain.agent.AgentJob;
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
    void anonymousRequestsCannotUseAnyResumeOrQueryItsOwnership()
    {
        AgentJobQuery query = new AgentJobQuery();
        query.setResumeId(20L);
        assertThrows(ServiceException.class, () -> service.selectJobs(query, null));
        verifyNoInteractions(mapper);
        assertNull(PageHelper.getLocalPage());
    }

    @Test
    void anonymousListAndDetailDoNotExposePersonalizedMatchScores()
    {
        AgentJob listed = new AgentJob();
        listed.setMatchScore(java.math.BigDecimal.valueOf(88));
        listed.setApplicationId(123L);
        listed.setAppliedFlag(1);
        listed.setJdJson("{\"responsibilities\":[\"公开职责\"],\"internal\":\"test-only\"}");
        listed.setCompanyDetails(java.util.Map.of("internal", "test-only"));
        when(mapper.selectJobList(any(), isNull())).thenReturn(java.util.List.of(listed));
        assertNull(service.selectJobs(new AgentJobQuery(), null).getItems().get(0).getMatchScore());
        assertNull(listed.getApplicationId());
        assertEquals(0, listed.getAppliedFlag());
        assertNull(listed.getJdJson());
        assertNull(listed.getCompanyDetails());
        assertEquals(java.util.List.of("公开职责"), listed.getResponsibilities());
        AgentJob detail = new AgentJob();
        detail.setMatchScore(java.math.BigDecimal.valueOf(77));
        when(mapper.selectJobById(26L, null)).thenReturn(detail);
        assertNull(service.selectJob(26L, null).getMatchScore());
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
