package com.ruoyi.enterprise.service.screening;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.JdAiProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ScreeningAiEvaluatorTest
{
    final ObjectMapper json = new ObjectMapper();
    HttpClient client;
    JdAiProperties properties;
    ScreeningAiEvaluator evaluator;
    final List<Map<String, Object>> candidates = List.of(Map.of("candidateId", 11L,
            "skills", List.of("Java工程开发"), "projects", List.of("订单平台开发")));

    @BeforeEach void setup()
    {
        client = mock(HttpClient.class);
        properties = new JdAiProperties();
        properties.setApiKey("synthetic-test-key");
        evaluator = new ScreeningAiEvaluator(properties, client);
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

    String envelope(String content, String stop) throws Exception
    {
        var result = json.createObjectNode(); result.put("stop_reason", stop);
        result.putArray("content").addObject().put("type", "text").put("text", content);
        return json.writeValueAsString(result);
    }

    @SuppressWarnings("unchecked")
    void response(int code, String content) throws Exception
    {
        HttpResponse<String> result = mock(HttpResponse.class);
        when(result.statusCode()).thenReturn(code); when(result.body()).thenReturn(content);
        when(client.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(result);
    }

    @Test void missingKeyDoesNotContactProvider()
    {
        properties.setApiKey("");
        assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of("title", "Java岗位"), candidates));
        verifyNoInteractions(client);
    }

    @Test void disabledServiceDoesNotContactProvider()
    {
        properties.setEnabled(false);
        assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates));
        verifyNoInteractions(client);
    }

    @Test void realProtocolAndNormalizedWeightsAreUsed() throws Exception
    {
        response(200, envelope(json.writeValueAsString(valid()), "end_turn"));
        var result = evaluator.evaluate(Map.of("title", "Java岗位"), candidates).get(0);
        assertEquals(70.0, result.get("totalScore"));
        assertEquals(50, result.get("evidenceCoverage"));
        assertNull(result.get("educationMatch"));
        assertEquals("llm", result.get("source"));
        var request = ArgumentCaptor.forClass(HttpRequest.class);
        verify(client).send(request.capture(), any(HttpResponse.BodyHandler.class));
        assertEquals("https://api.deepseek.com/anthropic/v1/messages", request.getValue().uri().toString());
        assertEquals("2023-06-01", request.getValue().headers().firstValue("anthropic-version").orElseThrow());
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
        assertEquals(70.0, evaluator.decode(raw.toString(), candidates).get(0).get("totalScore"));
    }

    @Test void fabricatedEvidenceIsRejected() throws Exception
    {
        var raw = valid(); ((ObjectNode)raw.path("results").get(0).path("dimensions").path("skillMatch")).put("evidence", "不存在的简历经历");
        assertThrows(ServiceException.class, () -> evaluator.decode(raw.toString(), candidates));
    }

    @Test void missingScoreIsNotReplacedBySeventy() throws Exception
    {
        var raw = valid(); var dimensions = raw.path("results").get(0).path("dimensions");
        for (var dimension : dimensions) ((ObjectNode)dimension).putNull("score");
        var result = evaluator.decode(raw.toString(), candidates).get(0);
        assertNull(result.get("totalScore")); assertEquals(0, result.get("evidenceCoverage"));
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
        response(200, envelope(json.writeValueAsString(valid()), "max_tokens"));
        assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates));
    }

    @Test void timeoutAndUpstreamErrorsDoNotLeakSecrets() throws Exception
    {
        response(401, "synthetic-private-body");
        assertFalse(assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates)).getMessage().contains("private"));
        when(client.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenThrow(new HttpTimeoutException("synthetic-private-body"));
        assertFalse(assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates)).getMessage().contains("private"));
    }

    @Test void insecureEndpointIsRejectedBeforeSending() throws Exception
    {
        properties.setBaseUrl("http://synthetic.invalid/anthropic");
        assertThrows(ServiceException.class, () -> evaluator.evaluate(Map.of(), candidates));
        verifyNoInteractions(client);
    }
}
