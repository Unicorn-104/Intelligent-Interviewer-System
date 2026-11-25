package com.ruoyi.web.controller.system;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.service.IImService;

class ImMessageSnapshotControllerTest
{
    @Test
    void snapshotBindsRequestedIdsAndUsesOnlyAuthenticatedViewer() throws Exception
    {
        var service = mock(IImService.class);
        var controller = new ImController();
        ReflectionTestUtils.setField(controller,"imService",service);
        var message = new ImMessage();
        message.setMessageId(31L);
        message.setType(5);
        message.setContent("{\"status\":\"approved\"}");
        when(service.selectMessageSnapshot(8L,12L,List.of(31L,32L))).thenReturn(List.of(message));
        try (var security = mockStatic(SecurityUtils.class))
        {
            var login = new LoginUser();
            login.setUserId(12L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            var mvc = MockMvcBuilders.standaloneSetup(controller).build();
            mvc.perform(get("/system/im/sessions/8/messages/snapshot")
                    .param("messageIds","31,32").param("userId","999"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].messageId").value(31))
                .andExpect(jsonPath("$.data[0].content").value("{\"status\":\"approved\"}"));
            verify(service).selectMessageSnapshot(8L,12L,List.of(31L,32L));
            mvc.perform(get("/system/im/sessions/8/messages/snapshot")).andExpect(status().isBadRequest());
            mvc.perform(get("/system/im/sessions/8/messages/snapshot").param("messageIds","invalid"))
                .andExpect(status().isBadRequest());
            verifyNoMoreInteractions(service);
        }
    }

    @Test
    void anonymousSnapshotCannotReachTheService()
    {
        SecurityContextHolder.clearContext();
        var service = mock(IImService.class);
        var controller = new ImController();
        ReflectionTestUtils.setField(controller,"imService",service);
        try
        {
            assertThrows(ServiceException.class,()->controller.messageSnapshot(8L,List.of(31L)));
            verifyNoInteractions(service);
        }
        finally { SecurityContextHolder.clearContext(); }
    }
}
