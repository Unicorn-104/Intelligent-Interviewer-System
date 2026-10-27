package com.ruoyi.web.controller.system;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.system.service.impl.ImReadReceiptService;

class ImReadReceiptControllerTest
{
    @Test void receiptUsesAuthenticatedViewerAndDisplayedMessageId() throws Exception
    {
        var service = mock(ImReadReceiptService.class);
        var controller = new ImReadReceiptController();
        ReflectionTestUtils.setField(controller,"receipts",service);
        when(service.acknowledge(12L,8L,31L)).thenReturn(Map.of("supported",true,"lastMessageId",31L));
        try(var security=mockStatic(SecurityUtils.class)) {
            var login=new LoginUser();login.setUserId(12L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build()
                .perform(put("/system/im/sessions/8/receipts").contentType("application/json")
                    .content("{\"lastMessageId\":31,\"userId\":999,\"peerId\":999}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.supported").value(true))
                .andExpect(jsonPath("$.data.lastMessageId").value(31));
            verify(service).acknowledge(12L,8L,31L);
        }
    }

    @Test void historyEndpointSerializesDeliveryStatusReturnedByRealImService() throws Exception
    {
        var messageMapper = mock(com.ruoyi.system.mapper.ImMessageMapper.class);
        var sessionMapper = mock(com.ruoyi.system.mapper.ImSessionMapper.class);
        var receipts = mock(ImReadReceiptService.class);
        var service = new com.ruoyi.system.service.impl.ImServiceImpl();
        ReflectionTestUtils.setField(service,"messageMapper",messageMapper);
        ReflectionTestUtils.setField(service,"sessionMapper",sessionMapper);
        ReflectionTestUtils.setField(service,"receipts",receipts);
        var session = new com.ruoyi.system.domain.ImSession();
        session.setSessionId(8L); session.setUserAId(11L); session.setUserBId(12L);
        var message = new com.ruoyi.system.domain.ImMessage();
        message.setMessageId(31L); message.setSenderId(11L); message.setType(4); message.setContent("合成表情");
        when(sessionMapper.selectSessionByIdAndUser(8L,11L)).thenReturn(session);
        when(messageMapper.selectMessageListBySession(8L)).thenReturn(java.util.List.of(message));
        doAnswer(call -> { message.setDeliveryStatus("delivered"); return null; })
                .when(receipts).decorate(eq(11L),eq(session),anyList());
        var controller = new ImController();
        ReflectionTestUtils.setField(controller,"imService",service);
        try(var security=mockStatic(SecurityUtils.class)) {
            var login=new LoginUser();login.setUserId(11L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build()
                .perform(get("/system/im/sessions/8/messages"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].deliveryStatus").value("delivered"))
                .andExpect(jsonPath("$.data[0].isMine").value(true));
            verify(receipts).decorate(eq(11L),eq(session),anyList());
        }
    }
}
