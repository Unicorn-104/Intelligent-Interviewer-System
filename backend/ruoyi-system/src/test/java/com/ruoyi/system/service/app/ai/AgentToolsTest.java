package com.ruoyi.system.service.app.ai;

import java.util.List;
import java.util.Map;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.service.agent.IAgentApplicationService;
import com.ruoyi.system.service.agent.IAgentJobService;
import com.ruoyi.system.service.app.IAppResumeService;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AgentToolsTest
{
    private final IAppResumeService resumes = mock(IAppResumeService.class);
    private final IAgentJobService jobs = mock(IAgentJobService.class);
    private final IAgentApplicationService applications = mock(IAgentApplicationService.class);
    private final AgentTools tools = new AgentTools(resumes, jobs, applications);
    private final ObjectMapper json = new ObjectMapper();

    @Test
    void identityAndUnknownArgumentsAreRejectedBeforeBusinessCalls() throws Exception
    {
        assertThrows(ServiceException.class, () -> tools.execute(null, null, "list_resumes", json.readTree("{}")));
        assertThrows(ServiceException.class, () -> tools.execute(17L, null, "get_resume", json.readTree("{\"resumeId\":5,\"userId\":18}")));
        assertThrows(ServiceException.class, () -> tools.execute(17L, null, "execute_sql", json.readTree("{}")));
        verifyNoInteractions(resumes, jobs, applications);
    }

    @Test
    void selectedResumeCannotBeChangedByModelAndEveryReadScopesOwner() throws Exception
    {
        assertThrows(ServiceException.class, () -> tools.execute(17L, 5L, "get_resume", json.readTree("{\"resumeId\":6}")));
        when(resumes.selectResume(17L, 5L)).thenReturn(new AppResume());
        tools.execute(17L, 5L, "get_resume", json.readTree("{\"resumeId\":5}"));
        verify(resumes).selectResume(17L, 5L);
        verify(resumes, never()).selectResume(17L, 6L);
    }

    @Test
    void interviewContextUsesOwnedApplicationAndItsAssociatedResume()
    {
        AgentApplication application = new AgentApplication();
        application.setId(91L);
        application.setJobId(42L);
        application.setResumeId(7L);
        AgentJob job = new AgentJob();
        job.setId(42L);
        job.setTitle("synthetic job");
        job.setStatusCode(1);
        AppResume resume = new AppResume();
        resume.setResumeId(7L);
        when(applications.selectApplication(17L, 91L)).thenReturn(application);
        when(jobs.selectJob(42L, 17L)).thenReturn(job);
        when(resumes.selectResume(17L, 7L)).thenReturn(resume);
        var context = tools.selectedContext(17L, null, 91L, "interview_preparation");
        assertEquals(7L, context.get("resumeId"));
        assertEquals(91L, context.get("applicationId"));
        assertEquals("synthetic job", ((Map<?, ?>)context.get("job")).get("title"));
        verify(resumes).selectResume(17L, 7L);
    }

    @Test
    void chatPreloadsSelectedResumeBeforeCallingModel()
    {
        AppResume resume = new AppResume();
        resume.setResumeId(7L);
        resume.setJobDirection("synthetic direction");
        when(resumes.selectResume(17L, 7L)).thenReturn(resume);
        var context = tools.selectedContext(17L, 7L, null, "chat");
        assertEquals(7L, ((Map<?, ?>) context.get("resume")).get("resumeId"));
        assertEquals("synthetic direction", ((Map<?, ?>) context.get("resume")).get("direction"));
        verify(resumes).selectResume(17L, 7L);
        verifyNoInteractions(jobs, applications);
    }

    @Test
    void chatRejectsInactiveApplicationResumeBeforeCallingModel()
    {
        AgentApplication application = new AgentApplication();
        application.setId(91L);
        application.setJobId(42L);
        application.setResumeId(7L);
        when(applications.selectApplication(17L, 91L)).thenReturn(application);
        when(jobs.selectJob(42L, 17L)).thenReturn(new AgentJob());
        when(resumes.selectResume(17L, 7L)).thenThrow(new ServiceException("unavailable"));
        ServiceException failure = assertThrows(ServiceException.class,
                () -> tools.selectedContext(17L, 7L, 91L, "chat"));
        assertTrue(failure.getMessage().contains("该次投递关联的简历已删除"));
        verify(resumes).selectResume(17L, 7L);
    }

    @Test
    void everyExplicitResumeIsValidatedButUnselectedChatNeedsNoResume()
    {
        for (String action : List.of("chat", "writing_polish"))
        {
            assertFalse(tools.selectedContext(17L, null, null, action).containsKey("resume"));
        }
        verifyNoInteractions(resumes, jobs, applications);
        when(resumes.selectResume(17L, 7L)).thenThrow(new ServiceException("not owned"));
        for (String action : List.of("chat", "writing_polish", "resume_analysis", "job_recommendation"))
        {
            ServiceException failure = assertThrows(ServiceException.class,
                    () -> tools.selectedContext(17L, 7L, null, action));
            assertTrue(failure.getMessage().contains("请重新选择有效简历"));
        }
    }

    @Test
    void chatPreloadsApplicationResumeAndOwnedJob()
    {
        AgentApplication application = new AgentApplication();
        application.setId(91L);
        application.setJobId(42L);
        application.setResumeId(7L);
        AppResume resume = new AppResume();
        resume.setResumeId(7L);
        when(applications.selectApplication(17L, 91L)).thenReturn(application);
        when(jobs.selectJob(42L, 17L)).thenReturn(new AgentJob());
        when(resumes.selectResume(17L, 7L)).thenReturn(resume);
        var context = tools.selectedContext(17L, null, 91L, "chat");
        assertEquals(7L, context.get("resumeId"));
        assertEquals(91L, context.get("applicationId"));
        assertEquals(7L, ((Map<?, ?>) context.get("resume")).get("resumeId"));
        verify(resumes).selectResume(17L, 7L);
    }

    @Test
    void interviewContextRejectsMissingApplicationResumeOrMismatchedResume()
    {
        AgentApplication application = new AgentApplication();
        application.setJobId(42L);
        application.setResumeId(7L);
        when(applications.selectApplication(17L, 91L)).thenReturn(application);
        assertThrows(ServiceException.class, () -> tools.selectedContext(17L, 8L, 91L, "interview_preparation"));
        application.setResumeId(null);
        assertThrows(ServiceException.class, () -> tools.selectedContext(17L, null, 91L, "interview_preparation"));
        assertThrows(ServiceException.class, () -> tools.selectedContext(17L, null, null, "interview_preparation"));
        verifyNoInteractions(resumes, jobs);
    }

    @Test
    void interviewDoesNotReadResumeOrJobForForeignApplication()
    {
        when(applications.selectApplication(18L, 91L)).thenThrow(new ServiceException("not owned"));
        assertThrows(ServiceException.class, () -> tools.selectedContext(18L, null, 91L, "interview_preparation"));
        verifyNoInteractions(resumes, jobs);
    }

    @Test
    void rejectsCoercedAndOverflowIds() throws Exception
    {
        for (String value : List.of("1.2", "\"5\"", "-1", "9223372036854775808", "null"))
            assertThrows(ServiceException.class, () -> tools.execute(17L, null, "get_resume", json.readTree("{\"resumeId\":" + value + "}")));
        verifyNoInteractions(resumes);
    }

    @Test
    void resumeProjectionOmitsAttachmentAndIdentityFields() throws Exception
    {
        AppResume resume = new AppResume();
        resume.setResumeId(5L); resume.setUserId(17L); resume.setFilePath("private-test-path");
        resume.setExtractedText("private-test-source"); resume.setResumeName("private-test-name");
        when(resumes.selectResume(17L, 5L)).thenReturn(resume);
        String data = json.writeValueAsString(tools.execute(17L, null, "get_resume", json.readTree("{\"resumeId\":5}")));
        assertFalse(data.contains("private-test")); assertFalse(data.contains("userId"));
    }

    @Test
    void searchBoundsAndOnlyActiveDetailsAreAllowed() throws Exception
    {
        assertThrows(ServiceException.class, () -> tools.execute(17L, null, "search_jobs", json.readTree("{\"page\":6}")));
        assertThrows(ServiceException.class, () -> tools.execute(17L, null, "search_jobs", json.readTree("{\"salaryMin\":-1}")));
        AgentJob job = new AgentJob(); job.setStatusCode(2);
        when(jobs.selectJob(91L, 17L)).thenReturn(job);
        assertThrows(ServiceException.class, () -> tools.execute(17L, null, "get_job_detail", json.readTree("{\"jobId\":91}")));
    }

    @Test
    void refreshOmitsJobsThatBecameUnavailableAndNeverUsesModelFields()
    {
        AgentJob active = new AgentJob(); active.setId(91L); active.setTitle("server-title"); active.setStatusCode(1);
        when(jobs.selectJob(91L, 17L)).thenReturn(active);
        when(jobs.selectJob(92L, 17L)).thenThrow(new ServiceException("unavailable"));
        var cards = tools.refreshCards(17L, new java.util.LinkedHashSet<>(List.of(91L, 92L)));
        assertEquals(1, cards.size()); assertEquals("server-title", cards.get(0).get("title"));
    }
}
