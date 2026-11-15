package com.ruoyi.system.service.app.ai;

import java.io.BufferedReader;
import java.io.StringReader;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.system.service.IModelProviderService;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AgentModelStreamTest
{
    private final AgentModelClient model = new AgentModelClient(mock(IModelProviderService.class));
    private final ObjectMapper json = new ObjectMapper();
    private AgentModelClient.Reply parse(String stream, List<String> deltas) throws Exception
    {
        return model.readStream(new BufferedReader(new StringReader(stream)), json.createArrayNode(),
                json.createArrayNode(), deltas::add, System.nanoTime() + TimeUnit.SECONDS.toNanos(5));
    }

    @Test
    void readsContentAndFinalUsageWithoutReasoningContent() throws Exception
    {
        List<String> deltas = new ArrayList<>();
        var reply = parse("""
                data: {"choices":[{"delta":{"reasoning_content":"private reasoning","content":"你好"}}]}

                data: {"choices":[{"delta":{"content":"世界"},"finish_reason":"stop"}],"usage":{"total_tokens":42}}

                data: [DONE]

                """, deltas);
        assertEquals(List.of("你好", "世界"), deltas);
        assertEquals("你好世界", reply.message().path("content").asText());
        assertEquals(42, reply.tokens());
        assertFalse(reply.message().toString().contains("reasoning"));
    }

    @Test
    void assemblesFragmentedToolCallArguments() throws Exception
    {
        var first = json.createObjectNode();
        var call = first.putArray("choices").addObject().putObject("delta").putArray("tool_calls").addObject();
        call.put("index", 0).put("id", "call1");
        call.putObject("function").put("name", "get_resume").put("arguments", "{\"resumeId\":");
        var second = json.createObjectNode();
        var choice = second.putArray("choices").addObject().put("finish_reason", "tool_calls");
        choice.putObject("delta").putArray("tool_calls").addObject().put("index", 0)
                .putObject("function").put("arguments", "5}");
        var reply = parse("data: " + first + "\n\ndata: " + second + "\n\ndata: [DONE]\n\n", new ArrayList<>());
        assertToolReply(reply);
    }

    @Test
    void finishReasonEndsReadWithoutWaitingForDoneOrSocketClose() throws Exception
    {
        BufferedReader reader = mock(BufferedReader.class);
        when(reader.readLine()).thenReturn("data: {\"choices\":[{\"delta\":{\"content\":\"synthetic answer\"},\"finish_reason\":\"stop\"}]}")
                .thenThrow(new AssertionError("must not wait for another network read"));
        List<String> output = new ArrayList<>();
        var reply = model.readStream(reader, json.createArrayNode(), json.createArrayNode(), output::add,
                System.nanoTime() + TimeUnit.SECONDS.toNanos(5));
        assertEquals("synthetic answer", reply.message().path("content").asText());
        assertEquals(List.of("synthetic answer"), output);
        verify(reader, times(1)).readLine();
        assertTrue(reply.tokens() > 0);
    }

    private void assertToolReply(AgentModelClient.Reply reply)
    {
        var call = reply.message().path("tool_calls").path(0);
        assertEquals("call1", call.path("id").asText());
        assertEquals("get_resume", call.path("function").path("name").asText());
        assertEquals("{\"resumeId\":5}", call.path("function").path("arguments").asText());
    }

    @Test
    void rejectsTruncatedAndErrorStreams()
    {
        assertThrows(IllegalStateException.class, () -> parse("data: [DONE]\n\n", new ArrayList<>()));
        assertThrows(IllegalStateException.class, () -> parse("data: {\"error\":{\"message\":\"synthetic\"}}\n\n", new ArrayList<>()));
    }

    @Test
    void acceptsLongAnswersAcrossManySmallStreamChunks() throws Exception
    {
        String content = "模拟简历分析与修改建议".repeat(1800);
        StringBuilder stream = new StringBuilder();
        for (int offset = 0; offset < content.length(); offset += 4)
        {
            var chunk = json.createObjectNode();
            chunk.putArray("choices").addObject().putObject("delta")
                    .put("content", content.substring(offset, Math.min(offset + 4, content.length())));
            stream.append("data: ").append(chunk).append("\n\n");
        }
        stream.append("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n");
        List<String> deltas = new ArrayList<>();
        assertEquals(content, parse(stream.toString(), deltas).message().path("content").asText());
        assertEquals(content, String.join("", deltas));
    }

    @Test
    void distinguishesOutputLimitsFromIncompleteStreams()
    {
        assertThrows(AgentModelClient.OutputLimitException.class, () -> parse(
                "data: {\"choices\":[{\"delta\":{\"content\":\"模拟未完成回答\"},\"finish_reason\":\"length\"}]}\n\ndata: [DONE]\n\n",
                new ArrayList<>()));
        var chunk = json.createObjectNode();
        chunk.putArray("choices").addObject().put("finish_reason", "stop")
                .putObject("delta").put("content", "x".repeat(32769));
        assertThrows(AgentModelClient.OutputLimitException.class, () -> parse(
                "data: " + chunk + "\n\ndata: [DONE]\n\n", new ArrayList<>()));
    }

    @Test
    void expiredCallDeadlineReportsTimeout()
    {
        assertThrows(java.util.concurrent.TimeoutException.class, () -> model.readStream(
                new BufferedReader(new StringReader("data: [DONE]\n\n")), json.createArrayNode(),
                json.createArrayNode(), ignored -> { }, System.nanoTime() - 1));
    }

    @Test
    void continuousProgressSurvivesOldNinetySecondLimitButNotAbsoluteDeadline()
    {
        AtomicLong clock = new AtomicLong();
        var budget = new AgentModelClient.StreamBudget(TimeUnit.SECONDS.toNanos(180), clock::get);
        for (long seconds : List.of(40L, 80L, 120L, 160L))
        {
            clock.set(TimeUnit.SECONDS.toNanos(seconds));
            assertFalse(budget.expired());
            budget.progress();
        }
        clock.set(TimeUnit.SECONDS.toNanos(180));
        budget.progress();
        assertTrue(budget.expired());
    }

    @Test
    void stalledStreamExpiresAfterIdleBudgetAndProgressResetsIdleClock()
    {
        AtomicLong clock = new AtomicLong();
        var budget = new AgentModelClient.StreamBudget(TimeUnit.SECONDS.toNanos(180), clock::get);
        clock.set(TimeUnit.SECONDS.toNanos(44));
        assertFalse(budget.expired());
        budget.progress();
        clock.set(TimeUnit.SECONDS.toNanos(88));
        assertFalse(budget.expired());
        clock.set(TimeUnit.SECONDS.toNanos(89));
        assertTrue(budget.expired());
        budget.progress();
        assertTrue(budget.expired());
    }

    @Test
    void onlyContentReasoningAndToolsRefreshProgressNotKeepAlive() throws Exception
    {
        AtomicInteger progress = new AtomicInteger();
        List<String> output = new ArrayList<>();
        var reply = model.readStream(new BufferedReader(new StringReader("""
                : keepalive

                data: {"choices":[{"delta":{}}]}

                data: {"choices":[{"delta":{"reasoning_content":"private reasoning"}}]}

                data: {"choices":[{"delta":{"content":"synthetic answer"},"finish_reason":"stop"}]}

                data: [DONE]

                """)), json.createArrayNode(), json.createArrayNode(), output::add,
                System.nanoTime() + TimeUnit.SECONDS.toNanos(5), progress::incrementAndGet);
        assertEquals(2, progress.get());
        assertEquals(List.of("synthetic answer"), output);
        assertFalse(reply.message().toString().contains("private reasoning"));
    }
}
