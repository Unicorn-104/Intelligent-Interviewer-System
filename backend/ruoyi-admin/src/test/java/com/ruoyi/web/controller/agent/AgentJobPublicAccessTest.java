package com.ruoyi.web.controller.agent;

import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.util.AntPathMatcher;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.framework.config.properties.PermitAllUrlProperties;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.domain.agent.AgentPage;
import com.ruoyi.system.service.agent.IAgentJobService;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class AgentJobPublicAccessTest
{
    private IAgentJobService service;
    private MockMvc mvc;

    @BeforeEach
    void setup()
    {
        service = mock(IAgentJobService.class);
        AgentJobController controller = new AgentJobController();
        ReflectionTestUtils.setField(controller, "jobService", service);
        mvc = MockMvcBuilders.standaloneSetup(controller, new AgentApplicationController()).build();
    }

    @AfterEach
    void clearAuthentication()
    {
        SecurityContextHolder.clearContext();
    }

    @Test
    void visitorsBrowseWithoutBorrowingAnIdentityFromRequestParameters() throws Exception
    {
        when(service.selectJobs(any(), isNull())).thenReturn(new AgentPage<>(List.of(), 1, 10, 0));
        mvc.perform(get("/agent/v1/jobs").param("userId", "999").param("city", "杭州"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.items").isArray());
        verify(service).selectJobs(argThat(query -> "杭州".equals(query.getCity())), isNull());
        SecurityContextHolder.getContext().setAuthentication(new AnonymousAuthenticationToken("test-only",
                "anonymousUser", AuthorityUtils.createAuthorityList("ROLE_ANONYMOUS")));
        AgentJob job = new AgentJob();
        job.setId(26L);
        when(service.selectJob(26L, null)).thenReturn(job);
        mvc.perform(get("/agent/v1/jobs/26").param("userId", "999"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.id").value(26));
        verify(service).selectJob(26L, null);
    }

    @Test
    void signedInJobQueriesStillUseTheAuthenticatedIdentity() throws Exception
    {
        LoginUser user = new LoginUser();
        user.setUserId(100L);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(user, null, List.of()));
        when(service.selectJobs(any(), eq(100L))).thenReturn(new AgentPage<>(List.of(), 1, 10, 0));
        mvc.perform(get("/agent/v1/jobs").param("userId", "999"))
                .andExpect(status().isOk());
        verify(service).selectJobs(any(AgentJobQuery.class), eq(100L));
    }

    @Test
    void actualAnonymousUrlScannerDoesNotOpenResumesApplicationsOrMessaging()
    {
        PermitAllUrlProperties properties = new PermitAllUrlProperties();
        properties.setApplicationContext(mvc.getDispatcherServlet().getWebApplicationContext());
        properties.afterPropertiesSet();
        AntPathMatcher matcher = new AntPathMatcher();
        for (String path : List.of("/agent/v1/jobs", "/agent/v1/jobs/26",
                "/agent/v1/jobs/categories", "/agent/v1/jobs/filter-options"))
        {
            assertTrue(properties.getUrls().stream().anyMatch(pattern -> matcher.match(pattern, path)), path);
        }
        for (String path : List.of("/agent/v1/jobs/26/resume-options", "/agent/v1/resumes",
                "/agent/v1/resumes/26", "/agent/v1/applications", "/system/im/sessions"))
        {
            assertFalse(properties.getUrls().stream().anyMatch(pattern -> matcher.match(pattern, path)), path);
        }
    }
}
