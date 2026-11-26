package com.ruoyi.system.service.conference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionStatus;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.ConferenceMapper;
import com.ruoyi.system.service.app.ai.AgentModelClient;

/**
 * 纯AI 面试自动出题：模型不可用时回退岗位技能题，并把题目与总数落库。
 */
public class InterviewOutlineServiceTest
{
    private InterviewOutlineService service;
    private ConferenceMapper conferenceMapper;
    private AgentModelClient model;

    @BeforeEach
    void setUp()
    {
        conferenceMapper = mock(ConferenceMapper.class);
        model = mock(AgentModelClient.class);
        PlatformTransactionManager transactionManager = mock(PlatformTransactionManager.class);
        when(transactionManager.getTransaction(any())).thenReturn(mock(TransactionStatus.class));
        service = new InterviewOutlineService();
        ReflectionTestUtils.setField(service, "conferenceMapper", conferenceMapper);
        ReflectionTestUtils.setField(service, "model", model);
        ReflectionTestUtils.setField(service, "transactionManager", transactionManager);
    }

    private Map<String, Object> context()
    {
        Map<String, Object> ctx = new LinkedHashMap<>();
        ctx.put("sessionId", 301L);
        ctx.put("mode", 1);
        ctx.put("positionId", 7L);
        ctx.put("positionTitle", "Java 开发工程师");
        return ctx;
    }

    @Test
    void fallbackUsesPositionSkillsBeforeGenericQuestions()
    {
        when(conferenceMapper.selectPositionSkills(7L)).thenReturn(List.of(
                Map.of("name", "Java"), Map.of("name", "MySQL")));

        List<Map<String, Object>> questions = service.fallbackQuestions(context());

        assertEquals(5, questions.size());
        assertEquals("「Java」项目实践", questions.get(0).get("topic"));
        assertEquals("「MySQL」项目实践", questions.get(1).get("topic"));
        // 两个技能题之后用通用开放题补齐到 5 道
        assertEquals("团队协作与分歧", questions.get(4).get("topic"));
    }

    @Test
    void ensureQuestionsWritesFiveQuestionsAndSyncsTotalWhenModelUnavailable()
    {
        when(conferenceMapper.selectSessionContext(301L)).thenReturn(context());
        when(conferenceMapper.selectPositionSkills(7L)).thenReturn(List.of());
        when(model.resolve()).thenThrow(new ServiceException("AI 服务未配置，请联系管理员", 503));

        service.ensureQuestions(301L);

        verify(conferenceMapper, times(5)).insertOutlineQuestion(anyMap());
        verify(conferenceMapper).updateMeetingTotalQuestions(301L, 5);
    }

    @Test
    void ensureQuestionsSkipsNonPureAiSession()
    {
        Map<String, Object> ctx = context();
        ctx.put("mode", 2);
        when(conferenceMapper.selectSessionContext(301L)).thenReturn(ctx);

        service.ensureQuestions(301L);

        verify(conferenceMapper, times(0)).insertOutlineQuestion(anyMap());
    }

    @Test
    void ensureQuestionsSkipsSessionThatAlreadyHasQuestions()
    {
        when(conferenceMapper.selectSessionContext(301L)).thenReturn(context());
        when(conferenceMapper.countOutlineQuestions(301L)).thenReturn(3);

        service.ensureQuestions(301L);

        verify(conferenceMapper, times(0)).insertOutlineQuestion(anyMap());
    }
}
