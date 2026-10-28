package com.ruoyi.enterprise.service.screening;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeoutException;
import java.util.function.Consumer;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.JdAiProperties;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.app.ai.AgentModelClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class ScreeningAiEvaluatorTest
{
    final ObjectMapper json = new ObjectMapper();
    AgentModelClient model;
    ModelProvider provider;
    ScreeningAiEvaluator evaluator;
    final List<Map<String, Object>> candidates = List.of(Map.of("candidateId", 11L,
            "skills", List.of("Java工程开发"), "projects", List.of("订单平台开发")));

    @BeforeEach void setup()
    {
        model = mock(AgentModelClient.class);
        provider = new ModelProvider();
        provider.setMppApiUrl("https://api.deepseek.com/chat/completions");
        provider.setMppApiKey("synthetic-test-key");
        provider.setMppModelName("deepseek-chat");
        when(model.resolve()).thenReturn(provider);
        evaluator = new ScreeningAiEvaluator(new JdAiProperties(), model);
    }

    void content(String text) throws Exception
    {
        doAnswer(invocation ->
        {
            Consumer<String> delta = invocation.getArgument(3);
            delta.accept(text);
            return null;
        }).when(model).complete(any(), any(), any(), any(), anyLong(), anyInt());
    }

    void failure(Throwable error) throws Exception
    {
        doThrow(error).when(model).complete(any(), any(), any(), any(), anyLong(), anyInt());
    }

    ObjectNode valid() throws Exception
    {
        ObjectNode item = json.createObjectNode();
        item.put("candidateId", 11);
        item.put("recommendation", "具备Java工程开发与订单平台开发的相关经验，建议进一步核实项目职责和交付成果。");
        var dimensions = item.putObject("dimensions");
        for (String key : ScreeningAiEvaluator.WEIGHTS.keySet())
        {
            var dimension = dimensions.putObject(key);
            dimension.putNull("score"); dimension.put("evidence", "");
        }
        dimensions.withObject("/skillMatch").put("score", 80).put("evidence", "Java工程开发");
        dimensions.withObject("/projectMatch").put("score", 60).put("evidence", "订单平台开发");
        ObjectNode result = json.createObjectNode(); result.putArray("results").add(item);
        return result;
    }

    @Test void refusesCrossCandidateScoringBeforeCallingProvider() throws Exception
    {
        assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of("title", "Java岗位"),
                List.of(candidates.get(0), Map.of("candidateId", 12L))));
        verify(model, never()).complete(any(), any(), any(), any(), anyLong(), anyInt());
    }

    @Test void missingProviderDoesNotContactModel() throws Exception
    {
        when(model.resolve()).thenThrow(new ServiceException("AI 服务未配置，请联系管理员", 503));
        assertEquals("AI 服务未配置，请联系管理员",
                assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of("title", "Java岗位"), candidates)).getMessage());
        verify(model, never()).complete(any(), any(), any(), any(), anyLong(), anyInt());
    }

    @Test void fixedWeightsWithMissingZeroAreUsedAndProviderModelIsRecorded() throws Exception
    {
        content(json.writeValueAsString(valid()));
        var result = evaluator.evaluate(Map.of("title", "Java岗位"), candidates).get(0);
        assertEquals(35.0, result.get("totalScore"));
        assertEquals(50, result.get("evidenceCoverage"));
        assertEquals(0.0, result.get("educationMatch"));
        assertEquals("llm", result.get("source"));
        assertEquals("deepseek-chat", result.get("model"));
        verify(model).complete(same(provider), any(), isNull(), any(), anyLong(), eq(6500));
    }

    @Test void proseWrappedJsonIsAccepted() throws Exception
    {
        String wrapped = "以下是分析结果：\n```json\n" + json.writeValueAsString(valid()) + "\n```\n以上结果仅供参考。";
        assertEquals(35.0, evaluator.decode(wrapped, candidates).get(0).get("totalScore"));
        String prose = "分析完成。" + json.writeValueAsString(valid()) + " 完毕。";
        assertEquals(35.0, evaluator.decode(prose, candidates).get(0).get("totalScore"));
    }

    @Test void excessEvidenceIsTruncatedInsteadOfRejected() throws Exception
    {
        var raw = valid();
        var skill = (ObjectNode) raw.path("results").get(0).path("dimensions").path("skillMatch");
        var quotes = skill.putArray("evidence");
        for (int i = 0; i < 13; i++) quotes.add("Java工程开发");
        var result = evaluator.decode(raw.toString(), candidates).get(0);
        assertEquals(35.0, result.get("totalScore"));
        @SuppressWarnings("unchecked")
        Map<String, Object> dimensions = (Map<String, Object>) result.get("dimensions");
        @SuppressWarnings("unchecked")
        List<String> kept = (List<String>) ((Map<String, Object>) dimensions.get("skillMatch")).get("evidence");
        assertEquals(8, kept.size());
    }

    @Test void unknownCandidateCannotReceiveAnotherCandidatesScore() throws Exception
    {
        var raw = valid(); ((ObjectNode)raw.path("results").get(0)).put("candidateId", 99);
        assertThrows(ServiceException.class, () -> evaluator.decode(raw.toString(), candidates));
    }

    @Test void exactSkillArrayCanBeUsedAsEvidence() throws Exception
    {
        var raw = valid();
        ((ObjectNode)raw.path("results").get(0).path("dimensions").path("skillMatch"))
                .put("evidence", "[\"Java工程开发\"]");
        assertEquals(35.0, evaluator.decode(raw.toString(), candidates).get(0).get("totalScore"));
    }

    @Test void fabricatedEvidenceIsRejected() throws Exception
    {
        var raw = valid(); ((ObjectNode)raw.path("results").get(0).path("dimensions").path("skillMatch")).put("evidence", "不存在的简历经历");
        assertThrows(ServiceException.class, () -> evaluator.decode(raw.toString(), candidates));
    }

    @Test void missingScoreDefaultsToZeroAndCountsTowardFixedTotal() throws Exception
    {
        var raw = valid(); var dimensions = raw.path("results").get(0).path("dimensions");
        for (var dimension : dimensions) ((ObjectNode)dimension).putNull("score");
        var result = evaluator.decode(raw.toString(), candidates).get(0);
        assertEquals(0.0, result.get("totalScore")); assertEquals(0, result.get("evidenceCoverage"));
        assertTrue(result.values().contains(0.0));
    }

    @Test void explicitZeroWithoutEvidenceIsAcceptedButPositiveScoreNeedsEvidence() throws Exception
    {
        var raw = valid();
        var education = (ObjectNode) raw.path("results").get(0).path("dimensions").path("educationMatch");
        education.put("score", 0); education.putArray("evidence");
        var result = evaluator.decode(raw.toString(), candidates).get(0);
        assertEquals(0.0, result.get("educationMatch"));
        assertEquals(35.0, result.get("totalScore"));
        assertEquals(50, result.get("evidenceCoverage"));
        education.put("score", 75);
        assertThrows(ServiceException.class, () -> evaluator.decode(raw.toString(), candidates));
    }

    @Test void outOfRangeAndMissingDimensionAreRejected() throws Exception
    {
        var raw = valid(); ((ObjectNode)raw.path("results").get(0).path("dimensions").path("skillMatch")).put("score", 101);
        assertThrows(ServiceException.class, () -> evaluator.decode(raw.toString(), candidates));
        ((ObjectNode)raw.path("results").get(0).path("dimensions")).remove("skillMatch");
        assertThrows(ServiceException.class, () -> evaluator.decode(raw.toString(), candidates));
    }

    @Test void duplicateIdsAndPartialBatchAreRejected() throws Exception
    {
        var raw = valid();
        assertThrows(ServiceException.class, () -> evaluator.decode(raw.toString(), List.of(candidates.get(0), Map.of("candidateId", 12L))));
        ((com.fasterxml.jackson.databind.node.ArrayNode)raw.path("results")).add(raw.path("results").get(0).deepCopy());
        assertThrows(ServiceException.class, () -> evaluator.decode(raw.toString(), List.of(candidates.get(0), Map.of("candidateId", 12L))));
    }

    @Test void truncatedOutputIsRejected() throws Exception
    {
        failure(new IllegalStateException("MODEL_OUTPUT_LIMIT"));
        assertTrue(assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates)).getMessage().contains("未完整输出"));
    }

    @Test void timeoutAndUpstreamErrorsDoNotLeakSecrets() throws Exception
    {
        failure(new IllegalStateException("MODEL_HTTP_401"));
        String auth = assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates)).getMessage();
        assertFalse(auth.contains("synthetic-test-key"));
        assertFalse(auth.contains("MODEL_HTTP_401"));
        failure(new TimeoutException("synthetic-private-body"));
        assertFalse(assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates)).getMessage().contains("private"));
        failure(new java.io.IOException("synthetic-private-body"));
        assertFalse(assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates)).getMessage().contains("private"));
    }

    @Test void rateLimitMapsToReadableFailure() throws Exception
    {
        failure(new IllegalStateException("MODEL_HTTP_429"));
        assertTrue(assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates)).getMessage().contains("限流"));
    }
}
