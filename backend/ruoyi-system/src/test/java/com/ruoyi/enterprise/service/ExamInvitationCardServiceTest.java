package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.mapper.ImMessageMapper;
import com.ruoyi.system.mapper.ImSessionMapper;

class ExamInvitationCardServiceTest
{
    private ExamInvitationCardService service(ImSessionMapper sessions, ImMessageMapper messages)
    {
        ExamInvitationCardService service = new ExamInvitationCardService();
        ReflectionTestUtils.setField(service, "sessions", sessions);
        ReflectionTestUtils.setField(service, "messages", messages);
        return service;
    }

    @Test void createsSessionAndWritesExamInvitationCard()
    {
        ImSessionMapper sessions = mock(ImSessionMapper.class);
        ImMessageMapper messages = mock(ImMessageMapper.class);
        when(sessions.selectSessionByUsers(9L, 101L)).thenReturn(null);
        when(sessions.insertSession(any(ImSession.class))).thenAnswer(call -> {
            ImSession row = call.getArgument(0);
            row.setSessionId(55L);
            return 1;
        });
        when(messages.insertMessage(any(ImMessage.class))).thenReturn(1);
        when(sessions.updateSessionOnSend(eq(55L), anyString(), eq(101L))).thenReturn(1);

        service(sessions, messages).sendCard(9L, 101L,
                "【笔试邀请·Java笔试试卷】Java工程师，请点击链接进入：https://app.local/user/exam?scheduleId=12",
                "【笔试邀请】Java笔试试卷");

        var sessionCaptor = org.mockito.ArgumentCaptor.forClass(ImSession.class);
        verify(sessions).insertSession(sessionCaptor.capture());
        assertEquals(9L, sessionCaptor.getValue().getUserAId());
        assertEquals(101L, sessionCaptor.getValue().getUserBId());

        var messageCaptor = org.mockito.ArgumentCaptor.forClass(ImMessage.class);
        verify(messages).insertMessage(messageCaptor.capture());
        ImMessage message = messageCaptor.getValue();
        assertEquals(5, message.getType());
        assertEquals(9L, message.getSenderId());
        assertTrue(message.getContent().startsWith("【笔试邀请·Java笔试试卷】"));
        assertTrue(message.getContent().endsWith("/user/exam?scheduleId=12"));
        verify(sessions).updateSessionOnSend(eq(55L), eq("【笔试邀请】Java笔试试卷"), eq(101L));
    }

    @Test void reusesExistingSessionAndRejectsInvalidParticipants()
    {
        ImSessionMapper sessions = mock(ImSessionMapper.class);
        ImMessageMapper messages = mock(ImMessageMapper.class);
        ImSession existing = new ImSession();
        existing.setSessionId(77L);
        when(sessions.selectSessionByUsers(9L, 101L)).thenReturn(existing);
        when(messages.insertMessage(any(ImMessage.class))).thenReturn(1);
        when(sessions.updateSessionOnSend(eq(77L), anyString(), eq(101L))).thenReturn(1);

        service(sessions, messages).sendCard(9L, 101L, "【笔试邀请·试卷】请进入考试", "【笔试邀请】试卷");
        verify(sessions, never()).insertSession(any(ImSession.class));
        verify(messages).insertMessage(any(ImMessage.class));

        assertThrows(ServiceException.class, () -> service(sessions, messages).sendCard(9L, 9L, "【笔试邀请】", "【笔试邀请】"));
        assertThrows(ServiceException.class, () -> service(sessions, messages).sendCard(null, 101L, "【笔试邀请】", "【笔试邀请】"));
    }
}
