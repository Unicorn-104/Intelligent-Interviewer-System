package com.ruoyi.web.controller.enterprise;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.Map;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.enterprise.service.IScreeningService;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class ScreeningControllerTest
{
    @Test void appUsesDedicatedAsyncEndpointWithAuthenticatedUser() throws Exception
    {
        var service = mock(IScreeningService.class);
        var controller = new ScreeningController(); ReflectionTestUtils.setField(controller, "screeningService", service);
        when(service.triggerScreeningAsync(3L, 7L, 20)).thenReturn(Map.of("taskId", 7L, "processing", true));
        try (var security = mockStatic(SecurityUtils.class))
        {
            LoginUser login = new LoginUser(); login.setUserId(3L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build().perform(post("/enterprise/screening/tasks/async")
                    .contentType(MediaType.APPLICATION_JSON).content("{\"positionId\":7}"))
                    .andExpect(status().isOk()).andExpect(jsonPath("$.code").value(200)).andExpect(jsonPath("$.data.processing").value(true));
            verify(service).triggerScreeningAsync(3L, 7L, 20);
            verify(service, never()).triggerScreening(any(), any(), any());
        }
    }

    @Test void legacyEndpointKeepsSynchronousCompletionContract() throws Exception
    {
        var service = mock(IScreeningService.class);
        var controller = new ScreeningController(); ReflectionTestUtils.setField(controller, "screeningService", service);
        when(service.triggerScreening(3L, 7L, 10)).thenReturn(Map.of("taskId", 7L, "processing", false, "passedCount", 2));
        try (var security = mockStatic(SecurityUtils.class))
        {
            LoginUser login = new LoginUser(); login.setUserId(3L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build().perform(post("/enterprise/screening/tasks")
                    .contentType(MediaType.APPLICATION_JSON).content("{\"positionId\":7,\"topN\":10}"))
                    .andExpect(status().isOk()).andExpect(jsonPath("$.data.processing").value(false));
            verify(service).triggerScreening(3L, 7L, 10);
        }
    }

    @Test void databaseFailureDoesNotExposeSqlOrInternalPaths() throws Exception
    {
        var service = mock(IScreeningService.class);
        var controller = new ScreeningController(); ReflectionTestUtils.setField(controller, "screeningService", service);
        when(service.listResults(3L, 7L)).thenThrow(new org.springframework.jdbc.BadSqlGrammarException(
                "synthetic-query", "select synthetic_private_field limit 1 LIMIT ?", new java.sql.SQLException("synthetic-private-driver-message")));
        try (var security = mockStatic(SecurityUtils.class))
        {
            LoginUser login = new LoginUser(); login.setUserId(3L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).setControllerAdvice(new ScreeningExceptionHandler())
                    .build().perform(get("/enterprise/screening/tasks/7/results"))
                    .andExpect(status().isOk()).andExpect(jsonPath("$.code").value(500))
                    .andExpect(jsonPath("$.msg").value("分析数据查询失败，请稍后重试；如持续出现，请更新服务器后端"))
                    .andExpect(content().string(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("synthetic_private"))));
        }
    }

    @Test void pollingEndpointReadsStatusWithoutTriggeringModel() throws Exception
    {
        var service = mock(IScreeningService.class);
        var controller = new ScreeningController(); ReflectionTestUtils.setField(controller, "screeningService", service);
        when(service.getTaskStatus(3L, 7L)).thenReturn(Map.of("taskId", 7L, "state", "completed", "processing", false));
        try (var security = mockStatic(SecurityUtils.class))
        {
            LoginUser login = new LoginUser(); login.setUserId(3L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build().perform(get("/enterprise/screening/tasks/7/status"))
                    .andExpect(status().isOk()).andExpect(jsonPath("$.data.state").value("completed"));
            verify(service).getTaskStatus(3L, 7L);
            verify(service, never()).triggerScreeningAsync(any(), any(), any());
        }
    }
}
