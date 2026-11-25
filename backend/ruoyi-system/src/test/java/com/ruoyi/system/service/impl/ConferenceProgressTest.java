package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.system.mapper.ConferenceMapper;

/**
 * 面试进度：题目总数按 t_int_outline 实时统计，不依赖 meeting_state 快照。
 */
public class ConferenceProgressTest
{
    private ConferenceServiceImpl service;
    private ConferenceMapper conferenceMapper;

    @BeforeEach
    void setUp()
    {
        conferenceMapper = mock(ConferenceMapper.class);
        service = new ConferenceServiceImpl();
        ReflectionTestUtils.setField(service, "conferenceMapper", conferenceMapper);
    }

    @Test
    void progressUsesLiveOutlineCountInsteadOfMeetingStateSnapshot()
    {
        Map<String, Object> ctx = new LinkedHashMap<>();
        ctx.put("candidateUserId", 11L);
        ctx.put("candidateId", 11L);
        ctx.put("positionId", 7L);
        ctx.put("mode", 1);
        ctx.put("status", 1);
        when(conferenceMapper.selectSessionContext(301L)).thenReturn(ctx);
        when(conferenceMapper.selectSessionInterviewers(301L)).thenReturn(List.of());
        when(conferenceMapper.selectPositionSkills(7L)).thenReturn(List.of());
        when(conferenceMapper.selectCandidateFlowHistory(11L)).thenReturn(List.of());
        // 会议状态快照为 0，异步自动出题已写入 3 题，进度应按实时统计返回
        when(conferenceMapper.selectMeetingState(301L)).thenReturn(new LinkedHashMap<>(Map.of(
                "totalQuestionNo", 0, "answeredCount", 0, "durationSeconds", 2700, "elapsedSeconds", 0)));
        when(conferenceMapper.countOutlineQuestions(301L)).thenReturn(3);
        when(conferenceMapper.selectOutlineAt(anyMap())).thenReturn(Map.of("topic", "第一题"));

        Map<String, Object> progress = service.getProgress(11L, 301L);

        assertEquals(3, progress.get("totalQuestionNo"));
        assertEquals(1, progress.get("currentQuestionNo"));
        verify(conferenceMapper).countOutlineQuestions(301L);
    }
}
