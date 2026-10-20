package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.screening.ScreeningAiEvaluator;
import com.ruoyi.system.mapper.DashboardMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

class ScreeningServiceImplTest
{
    ScreeningServiceImpl service;
    ScreeningMapper mapper;
    DashboardMapper dashboard;
    ScreeningAiEvaluator evaluator;
    PlatformTransactionManager transactions;

    @BeforeEach void setup()
    {
        service = new ScreeningServiceImpl();
        mapper = mock(ScreeningMapper.class); dashboard = mock(DashboardMapper.class);
        evaluator = mock(ScreeningAiEvaluator.class); transactions = mock(PlatformTransactionManager.class);
        ReflectionTestUtils.setField(service, "screeningMapper", mapper);
        ReflectionTestUtils.setField(service, "dashboardMapper", dashboard);
        ReflectionTestUtils.setField(service, "evaluator", evaluator);
        ReflectionTestUtils.setField(service, "transactionManager", transactions);
        when(transactions.getTransaction(any())).thenAnswer(call -> new SimpleTransactionStatus());
        when(dashboard.selectCompanyIdByUser(3L)).thenReturn(1L);
        when(mapper.selectPosition(1L, 7L)).thenReturn(Map.of("positionId", 7L, "title", "演示数据Java岗位"));
        when(mapper.selectCandidatesByPosition(7L)).thenReturn(List.of(new LinkedHashMap<>(Map.of("talentId", 11L, "resumeId", 21L))));
        when(mapper.selectOwnedCandidate(anyLong(), anyLong())).thenReturn(null);
        when(mapper.selectCandidateSkills(11L)).thenReturn(List.of("Java"));
        when(mapper.selectEducationEvidence(21L)).thenReturn(List.of(Map.of("major", "计算机科学")));
        when(mapper.selectWorkEvidence(21L)).thenReturn(List.of());
        when(mapper.selectProjectEvidence(21L)).thenReturn(List.of(Map.of("description", "Java订单开发")));
        when(mapper.selectPositionSkills(7L)).thenReturn(List.of("Java"));
        when(mapper.selectTaskStatus(1L, 7L)).thenReturn(Map.of("taskId", 7L, "state", "processing"));
        when(mapper.claimTask(eq(1L), eq(7L), anyString(), eq(1))).thenAnswer(call -> {
            when(mapper.lockTask(1L, 7L)).thenReturn(Map.of("runId", call.getArgument(2)));
            return 1;
        });
        when(mapper.updateTask(anyLong(), anyLong(), anyString(), anyString(), anyInt(), anyInt(), nullable(String.class))).thenReturn(1);
    }

    @AfterEach void cleanup() { service.shutdown(); }

    Map<String, Object> analysis()
    {
        return new LinkedHashMap<>(Map.of("resultId", 11L, "totalScore", 82.0, "source", "llm",
                "skillMatch", 82.0, "recommendation", "演示数据：Java订单项目与后端岗位相关，建议核实项目贡献。"));
    }

    @Test void unboundUserNeverFallsBackToCompanyOne()
    {
        when(dashboard.selectCompanyIdByUser(3L)).thenReturn(null);
        assertThrows(ServiceException.class, () -> service.triggerScreeningAsync(3L, 7L, 20));
        verifyNoInteractions(mapper, evaluator);
    }

    @Test void foreignPositionIsRejectedBeforeReadingResumes()
    {
        when(mapper.selectPosition(1L, 7L)).thenReturn(null);
        assertThrows(ServiceException.class, () -> service.triggerScreeningAsync(3L, 7L, 20));
        verify(mapper, never()).selectCandidatesByPosition(anyLong()); verifyNoInteractions(evaluator);
    }

    @Test void taskReturnsBeforeModelCompletesAndPersistsValidatedReportAtomically() throws Exception
    {
        CountDownLatch started = new CountDownLatch(1), release = new CountDownLatch(1);
        when(evaluator.evaluate(anyMap(), anyList())).thenAnswer(call -> {
            started.countDown(); release.await(2, TimeUnit.SECONDS); return List.of(analysis());
        });
        try
        {
            Map<String, Object> reply = service.triggerScreeningAsync(3L, 7L, 20);
            assertEquals(true, reply.get("processing"));
            assertTrue(started.await(1, TimeUnit.SECONDS));
            verify(mapper, never()).saveAnalysis(anyMap());
        }
        finally { release.countDown(); }
        verify(mapper, timeout(2000)).updateTask(eq(1L), eq(7L), anyString(), eq("completed"), eq(1), eq(1), isNull());
        var row = ArgumentCaptor.forClass(Map.class);
        verify(mapper).saveAnalysis(row.capture());
        assertEquals(1L, row.getValue().get("companyId"));
        assertEquals(7L, row.getValue().get("positionId"));
        assertEquals("llm", JSON.parseObject(row.getValue().get("report").toString()).get("source"));
        verify(transactions).commit(any());
    }

    @Test void legacyTriggerWaitsForCompletionRatherThanReportingPrematureSuccess()
    {
        when(evaluator.evaluate(anyMap(), anyList())).thenReturn(List.of(analysis()));
        when(mapper.updateTask(eq(1L), eq(7L), anyString(), eq("completed"), eq(1), eq(1), isNull())).thenAnswer(call -> {
            when(mapper.selectTaskStatus(1L, 7L)).thenReturn(Map.of("taskId", 7L, "state", "completed", "passedCount", 1));
            return 1;
        });
        Map<String, Object> reply = service.triggerScreening(3L, 7L, 20);
        assertEquals("completed", reply.get("state"));
        assertEquals(false, reply.get("processing"));
        assertEquals(20, reply.get("topN"));
        verify(mapper).saveAnalysis(anyMap());
    }

    @Test void providerFailurePreservesOldScoresAndReports()
    {
        when(evaluator.evaluate(anyMap(), anyList())).thenThrow(new ServiceException("模型暂不可用"));
        service.triggerScreeningAsync(3L, 7L, 20);
        verify(mapper, timeout(2000)).updateTask(eq(1L), eq(7L), anyString(), eq("failed"), eq(0), eq(0), eq("模型暂不可用"));
        verify(mapper, never()).saveAnalysis(anyMap()); verify(mapper, never()).updateMatchedScore(anyLong(), any());
    }

    @Test void duplicateTriggerDoesNotCallModelAgain()
    {
        when(mapper.claimTask(eq(1L), eq(7L), anyString(), eq(1))).thenReturn(0);
        assertEquals(true, service.triggerScreeningAsync(3L, 7L, 20).get("processing"));
        verifyNoInteractions(evaluator);
    }

    @Test void oldRuleScoresAreNotExposedAsAiAnalysis()
    {
        when(mapper.selectResultsByPosition(7L)).thenReturn(new ArrayList<>(List.of(new LinkedHashMap<>(Map.of("resultId", 11L, "totalScore", 95.0)))));
        var row = service.listResults(3L, 7L).get(0);
        assertNull(row.get("totalScore")); assertNull(row.get("skillMatch"));
        assertEquals("not_analyzed", row.get("source"));
    }

    @Test void jobResultReadsOnlyThatJobsReport()
    {
        when(mapper.selectResultsByPosition(7L)).thenReturn(new ArrayList<>(List.of(new LinkedHashMap<>(Map.of("resultId", 11L)))));
        when(mapper.selectAnalysis(1L, 7L, 11L)).thenReturn(Map.of("report", JSON.toJSONString(analysis()), "generatedAt", "2026-10-20 10:00:00"));
        assertEquals(82.0, ((Number)service.listResults(3L, 7L).get(0).get("totalScore")).doubleValue());
        verify(mapper, never()).selectLatestAnalysis(anyLong(), anyLong());
    }

    @Test void reportChecksCompanyBeforeReadingContent()
    {
        assertThrows(ServiceException.class, () -> service.getReport(3L, 11L));
        verify(mapper, never()).selectLatestAnalysis(anyLong(), anyLong());
    }

    @Test void saveFailureRollsBackWholeRefresh()
    {
        when(evaluator.evaluate(anyMap(), anyList())).thenReturn(List.of(analysis()));
        when(mapper.saveAnalysis(anyMap())).thenThrow(new IllegalStateException("synthetic-private-database-message"));
        service.triggerScreeningAsync(3L, 7L, 20);
        verify(transactions, timeout(2000)).rollback(any());
        verify(mapper, timeout(2000)).updateTask(eq(1L), eq(7L), anyString(), eq("failed"), eq(1), eq(0), eq("AI筛选失败，原有结果未变更，请稍后重试"));
        verify(transactions, never()).commit(any());
    }

    @Test void invalidReviewScoreCannotChangeCandidate()
    {
        when(mapper.selectOwnedCandidate(1L, 11L)).thenReturn(Map.of("talentId", 11L));
        assertThrows(ServiceException.class, () -> service.reviewResult(3L, 11L, true, Double.NaN));
        verify(mapper, never()).updateMatchedScore(anyLong(), any());
    }
}
