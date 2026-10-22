package com.ruoyi.web.controller.app;

import java.util.Map;
import java.util.Set;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.system.domain.app.ai.AgentRunRequest;
import com.ruoyi.system.service.app.ai.AppAiService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class AppAiControllerTest
{
    private final AppAiService service = mock(AppAiService.class);
    private MockMvc mvc;
    @BeforeEach
    void setup()
    {
        mvc = MockMvcBuilders.standaloneSetup(new AppAiController(service)).build();
        var login = new LoginUser(17L, 1L, new SysUser(), Set.of());
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(login, null, Set.of()));
    }
    @AfterEach
    void cleanup() { SecurityContextHolder.clearContext(); }

    @Test
    void ignoresForgedBodyIdentityAndUsesLoginForRunAndCancel() throws Exception
    {
        when(service.start(eq(17L), eq("synthetic-session"), any())).thenReturn(Map.of("id", "synthetic-run"));
        mvc.perform(post("/app/ai/sessions/synthetic-session/runs").contentType(MediaType.APPLICATION_JSON)
                .content("{\"requestId\":\"request-0000000001\",\"content\":\"test\",\"userId\":18}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.id").value("synthetic-run"));
        verify(service).start(17L, "synthetic-session", new AgentRunRequest("request-0000000001", "test", null));
        mvc.perform(post("/app/ai/runs/synthetic-run/cancel")).andExpect(status().isOk());
        verify(service).cancel(17L, "synthetic-run");
    }

    @Test
    void runBindsActionAndApplicationSelectionWithoutTrustingCallerIdentity() throws Exception
    {
        when(service.start(eq(17L), eq("synthetic-session"), any()))
                .thenReturn(Map.of("id", "synthetic-run"));
        mvc.perform(post("/app/ai/sessions/synthetic-session/runs").contentType(MediaType.APPLICATION_JSON)
                .content("{\"requestId\":\"request-0000000001\",\"content\":\"interview prep\","
                        + "\"applicationId\":91,\"action\":\"interview_preparation\",\"userId\":18}"))
                .andExpect(status().isOk());
        verify(service).start(17L, "synthetic-session",
                new AgentRunRequest("request-0000000001", "interview prep", null, 91L, "interview_preparation"));
    }

    @Test
    void rejectsUnknownActionBeforeCallingService() throws Exception
    {
        mvc.perform(post("/app/ai/sessions/synthetic-session/runs").contentType(MediaType.APPLICATION_JSON)
                .content("{\"requestId\":\"request-0000000001\",\"content\":\"test\",\"action\":\"unknown\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.code").value(400));
        verifyNoInteractions(service);
    }

    @Test
    void renameUsesAuthenticatedOwner() throws Exception
    {
        when(service.rename(17L, "synthetic-session", "synthetic title"))
                .thenReturn(Map.of("id", "synthetic-session", "title", "synthetic title"));
        mvc.perform(post("/app/ai/sessions/synthetic-session/rename").contentType(MediaType.APPLICATION_JSON)
                .content("{\"title\":\"synthetic title\",\"userId\":18}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.title").value("synthetic title"));
        verify(service).rename(17L, "synthetic-session", "synthetic title");
    }

    @Test
    void pinAndDeleteActionsUseAuthenticatedOwner() throws Exception
    {
        when(service.pin(17L, "synthetic-session", true))
                .thenReturn(Map.of("id", "synthetic-session", "pinned", true));
        mvc.perform(post("/app/ai/sessions/synthetic-session/pin").contentType(MediaType.APPLICATION_JSON)
                .content("{\"pinned\":true,\"userId\":18}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.pinned").value(true));
        verify(service).pin(17L, "synthetic-session", true);
        mvc.perform(delete("/app/ai/sessions/synthetic-session")).andExpect(status().isOk());
        verify(service).delete(17L, "synthetic-session");
        mvc.perform(post("/app/ai/sessions/batch-delete").contentType(MediaType.APPLICATION_JSON)
                .content("{\"ids\":[\"synthetic-session\"],\"userId\":18}"))
                .andExpect(status().isOk());
        verify(service).deleteBatch(17L, java.util.List.of("synthetic-session"));
    }

    @Test
    void rejectsInvalidBodyBeforeCallingService() throws Exception
    {
        mvc.perform(post("/app/ai/sessions/synthetic-session/runs").contentType(MediaType.APPLICATION_JSON)
                .content("{\"requestId\":\"short\",\"content\":\"\",\"resumeId\":-1}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.code").value(400));
        verifyNoInteractions(service);
    }
}
