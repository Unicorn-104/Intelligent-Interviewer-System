package com.ruoyi.web.controller.app;

import java.util.List;
import java.util.Map;
import java.util.Set;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.system.service.app.ai.AppAiMemoryService;
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

class AppAiMemoryControllerTest
{
    private final AppAiMemoryService service = mock(AppAiMemoryService.class);
    private MockMvc mvc;

    @BeforeEach
    void setup()
    {
        mvc = MockMvcBuilders.standaloneSetup(new AppAiMemoryController(service)).build();
        var login = new LoginUser(17L, 1L, new SysUser(), Set.of());
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(login, null, Set.of()));
    }

    @AfterEach
    void cleanup() { SecurityContextHolder.clearContext(); }

    @Test
    void memoryAndSummaryAlwaysUseAuthenticatedIdentity() throws Exception
    {
        when(service.read(17L)).thenReturn(Map.of("enabled", true, "revision", 0, "items", List.of()));
        mvc.perform(get("/app/ai/memories?userId=18")).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.revision").value(0));
        verify(service).read(17L);
        when(service.change(eq(17L), any())).thenReturn(Map.of("revision", 1));
        mvc.perform(post("/app/ai/memories").contentType(MediaType.APPLICATION_JSON)
                .content("{\"action\":\"save\",\"key\":\"city\",\"value\":\"synthetic city\",\"revision\":0,\"userId\":18}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.revision").value(1));
        verify(service).change(17L, new AppAiMemoryService.Change("save", "city", "synthetic city", null, 0L));
        when(service.summary(17L, "synthetic-session")).thenReturn(Map.of("content", ""));
        mvc.perform(get("/app/ai/sessions/synthetic-session/summary?userId=18")).andExpect(status().isOk());
        verify(service).summary(17L, "synthetic-session");
    }

    @Test
    void settingsOnlyExposeSwitchAndUseAuthenticatedIdentity() throws Exception
    {
        when(service.settings(17L)).thenReturn(Map.of("enabled", true, "revision", 0));
        mvc.perform(get("/app/ai/memory-settings?userId=18")).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.enabled").value(true))
                .andExpect(jsonPath("$.data.items").doesNotExist());
        verify(service).settings(17L);
        when(service.change(eq(17L), any())).thenReturn(Map.of("enabled", false, "revision", 1));
        mvc.perform(put("/app/ai/memory-settings").contentType(MediaType.APPLICATION_JSON)
                .content("{\"enabled\":false,\"revision\":0,\"userId\":18}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.enabled").value(false));
        verify(service).change(17L, new AppAiMemoryService.Change("settings", null, null, false, 0L));
    }

    @Test
    void malformedMemoryJsonReturnsGenericMessageWithoutPrivateValue() throws Exception
    {
        mvc.perform(post("/app/ai/memories").contentType(MediaType.APPLICATION_JSON)
                .content("{\"revision\":\"synthetic-private-text\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.code").value(400))
                .andExpect(jsonPath("$.msg").value("记忆参数无效"));
        verifyNoInteractions(service);
    }
}
