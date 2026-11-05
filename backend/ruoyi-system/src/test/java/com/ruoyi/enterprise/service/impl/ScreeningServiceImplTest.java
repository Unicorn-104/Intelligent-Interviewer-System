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
import com.ruoyi.enterprise.service.TalStatusService;
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
    TalStatusService talStatusService;

    @BeforeEach void setup()
    {
        service = new ScreeningServiceImpl();
        mapper = mock(ScreeningMapper.class); dashboard = mock(DashboardMapper.class);
        evaluator = mock(ScreeningAiEvaluator.class); transactions = mock(PlatformTransactionManager.class);
        talStatusService = mock(TalStatusService.class);
        ReflectionTestUtils.setField(service, "screeningMapper", mapper);
        ReflectionTestUtils.setField(service, "dashboardMapper", dashboard);
        ReflectionTestUtils.setField(service, "evaluator", evaluator);
        ReflectionTestUtils.setField(service, "transactionManager", transactions);
        ReflectionTestUtils.setField(service, "talStatusService", talStatusService);
        when(transactions.getTransaction(any())).thenAnswer(call -> new SimpleTransactionStatus());
        when(dashboard.selectCompanyIdByUser(3L)).thenReturn(1L);
        when(mapper.selectPosition(1L, 7L)).thenReturn(Map.of("positionId", 7L, "title", "演示数据Java岗位", "positionVersion", "p1"));
        when(mapper.selectCandidatesByPosition(7L)).thenReturn(List.of(new LinkedHashMap<>(Map.of("talentId", 11L, "resumeId", 21L, "resumeVersion", "v1"))));
        when(mapper.selectScreenableCandidates(7L)).thenReturn(List.of(new LinkedHashMap<>(Map.of("talentId", 11L, "resumeId", 21L, "resumeVersion", "v1"))));
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
        verify(mapper, timeout(2000)).updateTask(eq(1L), eq(7L), anyString(), eq("failed"), eq(0), eq(0), contains("模型暂不可用"));
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

    @Test void saveFailureRollsBackOnlyCurrentCandidate()
    {
        when(evaluator.evaluate(anyMap(), anyList())).thenReturn(List.of(analysis()));
        when(mapper.saveAnalysis(anyMap())).thenThrow(new IllegalStateException("synthetic-private-database-message"));
        service.triggerScreeningAsync(3L, 7L, 20);
        verify(transactions, timeout(2000)).rollback(any());
        verify(mapper, timeout(2000)).updateTask(eq(1L), eq(7L), anyString(), eq("failed"), eq(0), eq(0), contains("已完成的独立分析已保存"));
        verify(transactions, never()).commit(any());
    }

    @Test void incrementalSkipsExistingReportsWithoutContactingModel()
    {
        when(mapper.selectAnalyzedCandidates(1L, 7L)).thenReturn(List.of(Map.of("candidateId", 11L, "resumeVersion", "v1", "positionVersion", "p1")));
        when(mapper.selectTaskStatus(1L, 7L)).thenReturn(Map.of("state", "completed"));
        var reply = service.triggerScreeningAsync(3L, 7L, 20);
        assertEquals(false, reply.get("processing"));
        assertEquals(0, reply.get("candidateCount"));
        assertEquals(1, reply.get("skippedCount"));
        verifyNoInteractions(evaluator);
        verify(mapper, never()).claimTask(anyLong(), anyLong(), anyString(), anyInt());
        verify(mapper, never()).saveAnalysis(anyMap());
    }

    @Test void newCandidateOnlyGetsIndependentRequestAndExistingScoreIsNotWritten()
    {
        var original = new LinkedHashMap<String, Object>(Map.of("talentId", 12L, "resumeId", 22L, "resumeVersion", "v1"));
        var added = new LinkedHashMap<String, Object>(Map.of("talentId", 11L, "resumeId", 21L, "resumeVersion", "v1"));
        when(mapper.selectCandidatesByPosition(7L)).thenReturn(List.of(original, added));
        when(mapper.selectScreenableCandidates(7L)).thenReturn(List.of(original, added));
        when(mapper.selectAnalyzedCandidates(1L, 7L)).thenReturn(List.of(Map.of("candidateId", 12L, "resumeVersion", "v1", "positionVersion", "p1")));
        when(evaluator.evaluate(anyMap(), anyList())).thenAnswer(call -> {
            List<Map<String, Object>> input = call.getArgument(1);
            assertEquals(1, input.size()); assertEquals(11L, input.get(0).get("candidateId"));
            assertFalse(input.get(0).containsKey("totalScore"));
            return List.of(analysis());
        });
        var reply = service.triggerScreeningAsync(3L, 7L, 20);
        assertEquals(1, reply.get("skippedCount"));
        verify(mapper, timeout(2000)).saveAnalysis(argThat(row -> row.get("resultId").equals(11L)));
        verify(evaluator, timeout(2000).times(1)).evaluate(anyMap(), anyList());
        verify(mapper, never()).updateMatchedScore(anyLong(), any());
    }

    @Test void existingReportIsReadEvenIfResumeChangedUntilExplicitFullAnalysis()
    {
        when(mapper.selectAnalyzedCandidates(1L, 7L)).thenReturn(List.of(
                Map.of("candidateId", 11L, "resumeVersion", "old", "positionVersion", "p1")));
        when(mapper.selectCandidatesByPosition(7L)).thenReturn(List.of(
                new LinkedHashMap<>(Map.of("talentId", 11L, "resumeId", 21L, "resumeVersion", "new"))));
        when(mapper.selectScreenableCandidates(7L)).thenReturn(List.of(
                new LinkedHashMap<>(Map.of("talentId", 11L, "resumeId", 21L, "resumeVersion", "new"))));
        var reply = service.triggerScreeningAsync(3L, 7L, 20);
        assertEquals(1, reply.get("skippedCount"));
        assertEquals(false, reply.get("processing"));
        verifyNoInteractions(evaluator);
        verify(mapper, never()).saveAnalysis(anyMap());
    }

    @Test void cachedMissingDimensionsBecomeZeroWithoutModelOrDatabaseWrite()
    {
        var report = analysis();
        Map<String, Object> dimensions = new LinkedHashMap<>();
        for (String key : ScreeningAiEvaluator.WEIGHTS.keySet())
        {
            Map<String, Object> dimension = new LinkedHashMap<>();
            dimension.put("score", null); dimension.put("evidence", List.of());
            dimensions.put(key, dimension);
        }
        dimensions.put("skillMatch", Map.of("score", 80.0, "evidence", List.of("Java")));
        report.put("dimensions", dimensions);
        when(mapper.selectResultsByPosition(7L)).thenReturn(new ArrayList<>(List.of(
                new LinkedHashMap<>(Map.of("resultId", 11L)))));
        when(mapper.selectAnalysis(1L, 7L, 11L)).thenReturn(Map.of("report", JSON.toJSONString(report)));
        var row = service.listResults(3L, 7L).get(0);
        assertEquals(0.0, row.get("researchMatch"));
        assertEquals(0.0, row.get("awardMatch"));
        assertEquals(20.0, row.get("totalScore"));
        verifyNoInteractions(evaluator);
        verify(mapper, never()).saveAnalysis(anyMap());
    }

    @Test void fullAnalysisReevaluatesExistingCandidate()
    {
        when(mapper.selectAnalyzedCandidates(1L, 7L)).thenReturn(List.of(Map.of("candidateId", 11L, "resumeVersion", "v1", "positionVersion", "p1")));
        when(evaluator.evaluate(anyMap(), anyList())).thenReturn(List.of(analysis()));
        service.triggerScreeningAsync(3L, 7L, 20, true);
        verify(mapper, timeout(2000)).saveAnalysis(anyMap());
        verify(evaluator).evaluate(anyMap(), argThat(input -> input.size() == 1));
        verify(mapper, never()).selectAnalyzedCandidates(anyLong(), anyLong());
    }

    @Test void secondFailureDoesNotUndoFirstCandidateResult()
    {
        when(mapper.selectCandidatesByPosition(7L)).thenReturn(List.of(
                new LinkedHashMap<>(Map.of("talentId", 11L, "resumeId", 21L)),
                new LinkedHashMap<>(Map.of("talentId", 12L, "resumeId", 22L))));
        when(mapper.selectScreenableCandidates(7L)).thenReturn(List.of(
                new LinkedHashMap<>(Map.of("talentId", 11L, "resumeId", 21L)),
                new LinkedHashMap<>(Map.of("talentId", 12L, "resumeId", 22L))));
        when(mapper.claimTask(eq(1L), eq(7L), anyString(), eq(2))).thenAnswer(call -> {
            when(mapper.lockTask(1L, 7L)).thenReturn(Map.of("runId", call.getArgument(2))); return 1;
        });
        when(evaluator.evaluate(anyMap(), anyList())).thenReturn(List.of(analysis()))
                .thenThrow(new ServiceException("演示模型失败"));
        service.triggerScreeningAsync(3L, 7L, 20, true);
        verify(mapper, timeout(2000)).updateTask(eq(1L), eq(7L), anyString(), eq("failed"), eq(1), eq(1), contains("已保存"));
        verify(mapper, times(1)).saveAnalysis(anyMap());
        verify(transactions, times(1)).commit(any());
    }

    @Test void refreshReadsSavedResultsAndNeverCallsModel()
    {
        when(mapper.selectResultsByPosition(7L)).thenReturn(new ArrayList<>(List.of(new LinkedHashMap<>(Map.of("resultId", 11L)))));
        when(mapper.selectAnalysis(1L, 7L, 11L)).thenReturn(Map.of("report", JSON.toJSONString(analysis())));
        service.listResults(3L, 7L); service.listResults(3L, 7L);
        verifyNoInteractions(evaluator);
        verify(mapper, never()).saveAnalysis(anyMap());
        verify(mapper, never()).initTask(anyLong(), anyLong());
    }

    @Test void invalidReviewScoreCannotChangeCandidate()
    {
        when(mapper.selectOwnedCandidate(1L, 11L)).thenReturn(Map.of("talentId", 11L));
        assertThrows(ServiceException.class, () -> service.reviewResult(3L, 11L, true, Double.NaN, null));
        verify(mapper, never()).updateMatchedScore(anyLong(), any());
    }

    @Test void manualScoreWithoutConclusionCreatesManualReportAndScreensApplication()
    {
        when(mapper.selectOwnedCandidate(1L, 11L)).thenReturn(Map.of("talentId", 11L));
        when(mapper.selectApplicationResume(1L, 7L, 11L)).thenReturn(21L);
        when(mapper.countOwnedApplication(1L, 7L, 11L)).thenReturn(1);
        when(mapper.updateApplicationByCandidate(eq(7L), eq(11L), anyDouble(), anyInt(), anyList())).thenReturn(1);

        Map<String, Object> reply = service.reviewResult(3L, 11L, null, 72.0, 7L);

        assertNull(reply.get("approved"));
        assertEquals(1, reply.get("applicationStatus"));
        verify(mapper).saveAnalysis(argThat(row -> "manual".equals(row.get("source"))
                && row.get("resultId").equals(11L) && row.get("resumeId").equals(21L)));
        verify(mapper).updateApplicationByCandidate(7L, 11L, 72.0, 1, List.of(0, 1));
        // 人工评分只判定投递结果，不推进候选人状态
        verifyNoInteractions(talStatusService);
    }

    @Test void manualScoreBelowThresholdRejectsApplicationOnly()
    {
        when(mapper.selectOwnedCandidate(1L, 11L)).thenReturn(Map.of("talentId", 11L));
        when(mapper.countOwnedApplication(1L, 7L, 11L)).thenReturn(1);
        when(mapper.updateApplicationByCandidate(eq(7L), eq(11L), anyDouble(), anyInt(), anyList())).thenReturn(1);

        Map<String, Object> reply = service.reviewResult(3L, 11L, null, 55.0, 7L);

        assertEquals(2, reply.get("applicationStatus"));
        verify(mapper).updateApplicationByCandidate(7L, 11L, 55.0, 2, List.of(0, 1));
        verifyNoInteractions(talStatusService);
    }

    @Test void reviewRequiresEitherConclusionOrManualScore()
    {
        when(mapper.selectOwnedCandidate(1L, 11L)).thenReturn(Map.of("talentId", 11L));
        when(mapper.countOwnedApplication(1L, 7L, 11L)).thenReturn(1);

        assertThrows(ServiceException.class, () -> service.reviewResult(3L, 11L, null, null, 7L));
        verify(mapper, never()).updateApplicationByCandidate(anyLong(), anyLong(), any(), anyInt(), anyList());
        verify(mapper, never()).saveAnalysis(anyMap());
    }

    @Test void syncWritesBackOnlyApplicationsWithAiAnalysis()
    {
        when(mapper.selectPendingApplications(7L)).thenReturn(List.of(
                new LinkedHashMap<>(Map.of("applicationId", 31L, "talentId", 11L)),
                new LinkedHashMap<>(Map.of("applicationId", 32L, "talentId", 12L))));
        when(mapper.selectAnalysis(1L, 7L, 11L)).thenReturn(Map.of("report", JSON.toJSONString(analysis())));
        when(mapper.selectAnalysis(1L, 7L, 12L)).thenReturn(null);
        when(mapper.selectAnalyzedCandidates(1L, 7L)).thenReturn(List.of(
                Map.of("candidateId", 11L, "resumeVersion", "v1", "positionVersion", "p1")));

        Map<String, Object> reply = service.screenPendingApplications(3L, 7L);

        assertEquals(1, reply.get("writtenBackCount"));
        verify(mapper).updateApplicationScreened(31L, 82.0, 1);
        // 无 AI 分析结果（评估失败）的投递保持待筛选，等待人工评分
        verify(mapper, never()).updateApplicationScreened(eq(32L), any(), anyInt());
    }

    @Test void screenPendingApplicationsRequiresPosition()
    {
        assertThrows(ServiceException.class, () -> service.screenPendingApplications(3L, null));
        verify(mapper, never()).selectPendingApplications(anyLong());
        verifyNoInteractions(evaluator);
    }

    @Test void noPendingApplicationsCompletesWithoutTouchingApplications()
    {
        when(mapper.selectPendingApplications(7L)).thenReturn(List.of());

        Map<String, Object> result = service.screenPendingApplications(3L, 7L);

        assertEquals(7L, result.get("positionId"));
        assertEquals("completed", result.get("state"));
        assertTrue(String.valueOf(result.get("message")).contains("暂无待初筛"));
        verify(mapper, never()).updateApplicationScreened(anyLong(), any(), anyInt());
        verify(mapper, never()).saveAnalysis(anyMap());
        verifyNoInteractions(evaluator);
    }
}
