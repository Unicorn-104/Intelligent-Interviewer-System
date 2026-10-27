package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.enterprise.mapper.RescheduleRequestMapper;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.mapper.ImMessageMapper;
import com.ruoyi.system.mapper.ImSessionMapper;

class RescheduleMessageServiceTest
{
    @Test void candidateRequestCreatesPeerCardsAndNotices() throws Exception
    {
        var requests = mock(RescheduleRequestMapper.class);
        var sessions = mock(ImSessionMapper.class);
        var messages = mock(ImMessageMapper.class);
        var service = new RescheduleMessageService();
        ReflectionTestUtils.setField(service, "requests", requests);
        ReflectionTestUtils.setField(service, "sessions", sessions);
        ReflectionTestUtils.setField(service, "messages", messages);
        when(requests.selectCompanyUserIds(7L)).thenReturn(java.util.List.of(9L, 10L));
        when(sessions.selectSessionByUsers(anyLong(), eq(101L))).thenReturn(null);
        when(sessions.insertSession(any(ImSession.class))).thenAnswer(call -> {
            ImSession row = call.getArgument(0); row.setSessionId(55L); return 1;
        });
        when(messages.insertMessage(any(ImMessage.class))).thenReturn(1);
        when(sessions.updateSessionOnSend(eq(55L), anyString(), anyLong())).thenReturn(1);
        when(requests.insertNotification(anyLong(), anyString(), anyString(), anyString())).thenReturn(1);
        service.submitted(Map.ofEntries(
                Map.entry("requestId", 31L), Map.entry("appointmentId", 44L), Map.entry("companyId", 7L),
                Map.entry("requesterId", 101L), Map.entry("candidateName", "合成候选人"), Map.entry("positionName", "合成岗位"),
                Map.entry("originalStartTime", "2099-01-02 09:00:00"), Map.entry("originalEndTime", "2099-01-02 09:45:00"),
                Map.entry("newStartTime", "2099-01-03 10:00:00"), Map.entry("newEndTime", "2099-01-03 10:45:00"),
                Map.entry("reason", "合成原因"), Map.entry("status", "pending")));
        verify(requests).insertNotification(eq(9L), eq("收到面试改期申请"), contains("合成候选人"),
                eq("/enterprise/interview/reschedule-requests/31"));
        verify(requests).insertNotification(eq(10L), eq("收到面试改期申请"), anyString(), anyString());
        var captor = org.mockito.ArgumentCaptor.forClass(ImMessage.class);
        verify(messages, times(2)).insertMessage(captor.capture());
        Map<?, ?> card = new ObjectMapper().readValue(captor.getAllValues().get(0).getContent(), Map.class);
        assertEquals("interview_reschedule", card.get("kind"));
        assertEquals("pending", card.get("status"));
        assertEquals(31, ((Number) card.get("requestId")).intValue());
        assertTrue(captor.getAllValues().stream().allMatch(m -> m.getType() == 5));
        verify(sessions, times(2)).insertSession(any(ImSession.class));
    }

    @Test void directChangeNotifiesCandidateWithOldAndNewTimes() throws Exception
    {
        var requests = mock(RescheduleRequestMapper.class);
        var sessions = mock(ImSessionMapper.class);
        var messages = mock(ImMessageMapper.class);
        var service = new RescheduleMessageService();
        ReflectionTestUtils.setField(service, "requests", requests);
        ReflectionTestUtils.setField(service, "sessions", sessions);
        ReflectionTestUtils.setField(service, "messages", messages);
        var existing = new ImSession(); existing.setSessionId(55L); existing.setUserAId(9L); existing.setUserBId(101L);
        when(sessions.selectSessionByUsers(9L, 101L)).thenReturn(existing);
        when(messages.insertMessage(any(ImMessage.class))).thenReturn(1);
        when(sessions.updateSessionOnSend(eq(55L), anyString(), eq(101L))).thenReturn(1);
        when(requests.insertNotification(anyLong(), anyString(), anyString(), anyString())).thenReturn(1);
        service.changed(9L, Map.of("appointmentId", 44L, "candidateUserId", 101L, "positionTitle", "合成岗位",
                        "originalStartTime", "2099-01-02 09:00", "originalEndTime", "2099-01-02 09:45",
                        "startTime", "2099-01-03 10:00", "endTime", "2099-01-03 10:45"));
        var captor = org.mockito.ArgumentCaptor.forClass(ImMessage.class);
        verify(messages).insertMessage(captor.capture());
        Map<?, ?> card = new ObjectMapper().readValue(captor.getValue().getContent(), Map.class);
        assertEquals("changed", card.get("status"));
        assertEquals("2099-01-02 09:00", card.get("originalStartTime"));
        assertEquals("2099-01-03 10:00", card.get("newStartTime"));
        verify(requests).insertNotification(eq(101L), eq("面试改期通知"), contains("2099-01-03"),
                eq("/candidate/interview/appointments/44"));
    }
}
