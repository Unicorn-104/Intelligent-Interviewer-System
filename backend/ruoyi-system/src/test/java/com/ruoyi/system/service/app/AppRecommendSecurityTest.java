package com.ruoyi.system.service.app;

import java.util.List;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.domain.app.*;
import com.ruoyi.system.mapper.app.AppJobMapper;
import com.ruoyi.system.service.IModelProviderService;
import com.ruoyi.system.service.app.impl.AppRecommendServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AppRecommendSecurityTest
{
    private final IAppResumeService resumes = mock(IAppResumeService.class);
    private final IAppJobService jobs = mock(IAppJobService.class);
    private final IModelProviderService providers = mock(IModelProviderService.class);
    private final AppJobMapper mapper = mock(AppJobMapper.class);
    private final StubService service = new StubService();
    private final AppRecommendRequest request = new AppRecommendRequest();

    @BeforeEach
    void setup()
    {
        ReflectionTestUtils.setField(service, "resumeService", resumes);
        ReflectionTestUtils.setField(service, "jobService", jobs);
        ReflectionTestUtils.setField(service, "modelProviderService", providers);
        ReflectionTestUtils.setField(service, "jobMapper", mapper);
        request.setResumeId(5L);
        when(resumes.selectResume(17L, 5L)).thenReturn(new AppResume());
        AppJob job = new AppJob();
        job.setPositionId(91L);
        when(jobs.selectJobs(17L, null, null, 20)).thenReturn(List.of(job));
        ModelProvider provider = new ModelProvider();
        provider.setMppStatus(1);
        provider.setMppApiKey("synthetic-test-key");
        when(providers.selectModelProviderList(any())).thenReturn(List.of(provider));
        when(mapper.selectAvailableRecommendationIds(List.of(91L))).thenReturn(List.of(91L));
    }

    @Test
    void refusesMissingIdentityBeforeReadingData()
    {
        assertEquals(401, assertThrows(ServiceException.class, () -> service.recommend(null, request)).getCode());
        assertThrows(ServiceException.class, () -> service.recommend(0L, request));
        verifyNoInteractions(resumes, jobs, providers, mapper);
    }

    @Test
    void rejectsInvalidParametersAtServiceBoundary()
    {
        assertThrows(ServiceException.class, () -> service.recommend(17L, null));
        request.setResumeId(-1L);
        assertThrows(ServiceException.class, () -> service.recommend(17L, request));
        request.setResumeId(5L);
        request.setKeyword("x".repeat(101));
        assertThrows(ServiceException.class, () -> service.recommend(17L, request));
        request.setKeyword(null);
        request.setFilter("arbitrary");
        assertThrows(ServiceException.class, () -> service.recommend(17L, request));
        verifyNoInteractions(resumes, jobs, providers, mapper);
    }

    @Test
    void ownershipFailureCannotFallBackOrReachModel()
    {
        when(resumes.selectResume(17L, 5L)).thenThrow(new ServiceException("not accessible"));
        assertThrows(ServiceException.class, () -> service.recommend(17L, request));
        verifyNoInteractions(jobs, providers, mapper);
        assertEquals(0, service.calls);
    }

    @Test
    void excludesForeignAndFractionalIdsAndDeduplicates()
    {
        service.response = "{\"recommendations\":["
                + "{\"positionId\":999,\"matchScore\":100},"
                + "{\"positionId\":91.5,\"matchScore\":100},"
                + "{\"positionId\":91,\"matchScore\":70},"
                + "{\"positionId\":91,\"matchScore\":99}]}";
        List<AppJobRecommendation> result = service.recommend(17L, request);
        assertEquals(1, result.size());
        assertEquals(91L, result.get(0).getPositionId());
        assertEquals(70, result.get(0).getMatchScore());
        verify(mapper).selectAvailableRecommendationIds(List.of(91L));
    }

    @Test
    void removesJobsWithdrawnDuringModelCall()
    {
        when(mapper.selectAvailableRecommendationIds(anyList())).thenReturn(List.of());
        assertTrue(service.recommend(17L, request).isEmpty());
    }

    @Test
    void fallbackAlsoChecksAvailabilityAndFailsClosedOnDatabaseError()
    {
        service.fail = true;
        when(mapper.selectAvailableRecommendationIds(anyList())).thenReturn(List.of());
        assertTrue(service.recommend(17L, request).isEmpty());
        when(mapper.selectAvailableRecommendationIds(anyList())).thenThrow(new IllegalStateException("unavailable"));
        assertThrows(IllegalStateException.class, () -> service.recommend(17L, request));
    }

    @Test
    void promptOmitsUnnecessaryResumeIdentifiers()
    {
        AppResume resume = new AppResume();
        resume.setResumeName("synthetic-private-title");
        resume.setFilePath("private-test-path");
        resume.setExtractedText("private-test-original");
        when(resumes.selectResume(17L, 5L)).thenReturn(resume);
        service.recommend(17L, request);
        assertFalse(service.prompt.contains("synthetic-private-title"));
        assertFalse(service.prompt.contains("private-test-path"));
        assertFalse(service.prompt.contains("private-test-original"));
    }

    private static class StubService extends AppRecommendServiceImpl
    {
        String response = "{\"recommendations\":[{\"positionId\":91,\"matchScore\":90}]}";
        boolean fail;
        int calls;
        String prompt;

        @Override
        protected String callDeepSeek(ModelProvider provider, String prompt)
        {
            calls++;
            this.prompt = prompt;
            if (fail) throw new IllegalStateException("synthetic failure");
            return response;
        }
    }
}
