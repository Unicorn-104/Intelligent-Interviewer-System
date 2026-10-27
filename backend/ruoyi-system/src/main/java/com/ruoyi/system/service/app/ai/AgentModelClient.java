package com.ruoyi.system.service.app.ai;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.IModelProviderService;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Component;

/** OpenAI-compatible streaming protocol; provider secrets never leave this boundary. */
@Component
public class AgentModelClient
{
    private static final int MAX_OUTPUT_TOKENS = 8192;
    private static final int MAX_OUTPUT_CHARS = 32768;
    public record Reply(JsonNode message, int tokens) { }
    static final class OutputLimitException extends IllegalStateException
    {
        OutputLimitException() { super("MODEL_OUTPUT_LIMIT"); }
    }
    private final IModelProviderService providers;
    private final ObjectMapper json = new ObjectMapper();
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10))
            .followRedirects(HttpClient.Redirect.NEVER).build();
    private final ScheduledExecutorService timer = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread thread = new Thread(r, "capp-ai-http-timeout"); thread.setDaemon(true); return thread;
    });

    public AgentModelClient(IModelProviderService providers) { this.providers = providers; }

    public ModelProvider resolve()
    {
        return providers.selectModelProviderList(new ModelProvider()).stream()
                .filter(p -> Integer.valueOf(1).equals(p.getMppStatus()))
                .filter(p -> p.getMppApiKey() != null && !p.getMppApiKey().isBlank())
                .findFirst().orElseThrow(() -> new ServiceException("AI 服务未配置，请联系管理员", 503));
    }

    public Reply complete(ModelProvider provider, ArrayNode messages, JsonNode tools,
            Consumer<String> delta, long deadlineNanos) throws Exception
    {
        return complete(provider, messages, tools, delta, deadlineNanos, MAX_OUTPUT_TOKENS);
    }

    public Reply complete(ModelProvider provider, ArrayNode messages, JsonNode tools,
            Consumer<String> delta, long deadlineNanos, int maxOutputTokens) throws Exception
    {
        String url = provider.getMppApiUrl();
        URI uri = URI.create(url == null || url.isBlank() ? "https://api.deepseek.com/chat/completions" : url);
        // A provider is administrator-controlled. Never accept endpoints from the conversation.
        if (!"https".equalsIgnoreCase(uri.getScheme()) || uri.getHost() == null
                || uri.getUserInfo() != null || uri.getFragment() != null)
            throw new ServiceException("AI 服务地址配置无效", 503);
        long remaining = Math.min(90000, TimeUnit.NANOSECONDS.toMillis(deadlineNanos - System.nanoTime()));
        if (remaining <= 0) throw new java.util.concurrent.TimeoutException();
        long callDeadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(remaining);
        String model = provider.getMppModelName();
        var body = json.createObjectNode();
        body.put("model", model == null || model.isBlank() ? "deepseek-chat" : model);
        body.set("messages", messages);
        if (tools != null && !tools.isEmpty())
        {
            body.set("tools", tools);
            body.put("tool_choice", "auto");
        }
        body.put("stream", true);
        body.putObject("stream_options").put("include_usage", true);
        body.put("temperature", 0.2);
        body.put("max_tokens", Math.max(128, Math.min(MAX_OUTPUT_TOKENS, maxOutputTokens)));
        HttpRequest request = HttpRequest.newBuilder(uri).timeout(Duration.ofMillis(remaining))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + provider.getMppApiKey())
                .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body))).build();
        HttpResponse<InputStream> response = http.send(request, HttpResponse.BodyHandlers.ofInputStream());
        try (InputStream input = response.body())
        {
            if (response.statusCode() != 200) throw new IllegalStateException("MODEL_HTTP_" + response.statusCode());
            long bodyTime = Math.max(1, TimeUnit.NANOSECONDS.toMillis(callDeadline - System.nanoTime()));
            var timeout = timer.schedule(() -> { try { input.close(); } catch (Exception ignored) { } }, bodyTime, TimeUnit.MILLISECONDS);
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8)))
            {
                return readStream(reader, messages, tools, delta, callDeadline);
            }
            catch (java.io.IOException error)
            {
                if (System.nanoTime() >= callDeadline)
                    throw new java.net.http.HttpTimeoutException("MODEL_TIMEOUT");
                throw error;
            }
            finally { timeout.cancel(false); }
        }
    }

    Reply readStream(BufferedReader reader, ArrayNode messages, JsonNode tools,
            Consumer<String> delta, long deadlineNanos) throws Exception
    {
        StringBuilder content = new StringBuilder();
        Map<Integer, Call> calls = new LinkedHashMap<>();
        int tokens = 0, chars = 0;
        boolean finished = false;
        for (String line; (line = reader.readLine()) != null; )
        {
            if (Thread.currentThread().isInterrupted()) throw new InterruptedException();
            if (System.nanoTime() > deadlineNanos) throw new java.util.concurrent.TimeoutException();
            chars += line.length();
            if (chars > 2000000) throw new IllegalStateException("MODEL_RESPONSE_LIMIT");
            if (!line.startsWith("data:")) continue;
            String data = line.substring(5).trim();
            if (data.equals("[DONE]")) break;
            if (data.isEmpty()) continue;
            JsonNode chunk = json.readTree(data);
            if (chunk.has("error")) throw new IllegalStateException("MODEL_STREAM_ERROR");
            tokens = Math.max(tokens, chunk.path("usage").path("total_tokens").asInt());
            JsonNode choice = chunk.path("choices").path(0);
            String finish = choice.path("finish_reason").asText("");
            if (finish.equals("stop") || finish.equals("tool_calls")) finished = true;
            JsonNode part = choice.path("delta");
            if (part.path("content").isTextual())
            {
                String value = part.path("content").asText();
                content.append(value);
                if (content.length() > MAX_OUTPUT_CHARS) throw new OutputLimitException();
                if (!value.isEmpty()) delta.accept(value);
            }
            if (finish.equals("length")) throw new OutputLimitException();
            for (JsonNode call : part.path("tool_calls"))
            {
                int index = call.path("index").asInt(-1);
                if (index < 0 || index > 3) throw new IllegalStateException("TOOL_CALL_LIMIT");
                Call target = calls.computeIfAbsent(index, key -> new Call());
                target.id.append(call.path("id").asText(""));
                target.name.append(call.path("function").path("name").asText(""));
                target.arguments.append(call.path("function").path("arguments").asText(""));
                if (target.arguments.length() > 6000 || target.name.length() > 80 || target.id.length() > 100)
                    throw new IllegalStateException("TOOL_ARGUMENT_LIMIT");
            }
        }
        if (!finished) throw new IllegalStateException("MODEL_STREAM_INCOMPLETE");
        var message = json.createObjectNode().put("role", "assistant").put("content", content.toString());
        if (!calls.isEmpty())
        {
            ArrayNode toolCalls = message.putArray("tool_calls");
            for (Call call : calls.values())
            {
                if (call.id.isEmpty() || call.name.isEmpty()) throw new IllegalStateException("INVALID_TOOL_CALL");
                var node = toolCalls.addObject().put("id", call.id.toString()).put("type", "function");
                node.putObject("function").put("name", call.name.toString()).put("arguments", call.arguments.toString());
            }
        }
        // Conservative fallback when a compatible provider does not return token usage.
        int estimated = json.writeValueAsString(messages).length() + json.writeValueAsString(tools).length()
                + content.length() + calls.values().stream().mapToInt(c -> c.arguments.length()).sum();
        return new Reply(message, tokens > 0 ? tokens : estimated);
    }

    private static class Call
    {
        final StringBuilder id = new StringBuilder(), name = new StringBuilder(), arguments = new StringBuilder();
    }

    @PreDestroy
    void close() { timer.shutdownNow(); }
}
