package com.ruoyi.web.controller.app;

import java.util.List;
import java.util.Set;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.system.domain.app.AppJob;
import com.ruoyi.system.service.app.IAppJobService;
import com.ruoyi.system.service.agent.IAgentJobService;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.common.exception.ServiceException;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.test.util.ReflectionTestUtils;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AppJobControllerTest
{
    private final IAppJobService service = mock(IAppJobService.class);
    private final IAgentJobService publicService = mock(IAgentJobService.class);
    private AppJobController controller;
    private MockMvc mvc;

    @BeforeEach
    void setup()
    {
        controller = new AppJobController();
        ReflectionTestUtils.setField(controller, "jobService", service);
        ReflectionTestUtils.setField(controller, "publicJobService", publicService);
        mvc = MockMvcBuilders.standaloneSetup(controller).build();
        SecurityContextHolder.clearContext();
    }

    @AfterEach
    void cleanup() { SecurityContextHolder.clearContext(); }

    @Test
    void anonymousJobBrowsePassesNullUserId() throws Exception
    {
        when(service.selectJobs(null, null, null, 20)).thenReturn(List.of(new AppJob()));

        mvc.perform(get("/app/jobs"))
                .andExpect(status().isOk());

        verify(service).selectJobs(null, null, null, 20);
    }

    @Test
    void authenticatedJobBrowseKeepsUserIdForPersonalizedResults() throws Exception
    {
        var login = new LoginUser(17L, 1L, new SysUser(), Set.of());
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(login, null, Set.of()));
        when(service.selectJobs(17L, null, null, 20)).thenReturn(List.of());

        mvc.perform(get("/app/jobs"))
                .andExpect(status().isOk());

        verify(service).selectJobs(17L, null, null, 20);
    }

    @Test
    void publicSearchKeepsFiltersAndPagingWithoutPersonalResumeContext() throws Exception
    {
        mvc.perform(get("/app/jobs/search").param("city", "杭州").param("sort", "salary")
                .param("page", "2").param("size", "10").param("resumeId", "99"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.code").value(200));
        verify(publicService).selectJobs(argThat(query -> "杭州".equals(query.getCity())
                && "salary".equals(query.getSort()) && query.getPage() == 2
                && query.getSize() == 10 && query.getResumeId() == null), isNull());
    }

    @Test
    void publicFiltersAndDetailsDoNotReadPrivateUserContext() throws Exception
    {
        var job = new AgentJob();
        job.setStatusCode(1);
        when(publicService.selectJob(7L, null)).thenReturn(job);
        mvc.perform(get("/app/jobs/filter-options")).andExpect(status().isOk());
        mvc.perform(get("/app/jobs/public/7")).andExpect(status().isOk());
        verify(publicService).selectJobFilterOptions();
        verify(publicService).selectJob(7L, null);
    }

    @Test
    void offlineJobsAreNotExposedByPublicDetail()
    {
        var job = new AgentJob();
        job.setStatusCode(2);
        when(publicService.selectJob(7L, null)).thenReturn(job);
        assertThrows(ServiceException.class, () -> controller.publicDetail(7L));
    }
}
