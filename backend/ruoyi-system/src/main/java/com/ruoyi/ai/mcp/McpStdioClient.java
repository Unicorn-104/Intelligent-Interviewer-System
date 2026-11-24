package com.ruoyi.ai.mcp;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicLong;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * 极简 MCP stdio 客户端：按 JSON-RPC 2.0 行协议与外部 MCP Server 通信。
 *
 * <p>不引入第三方 SDK，避免与 Spring Boot / Jackson 版本冲突；只实现本系统需要的
 * initialize、tools/list、tools/call 三个方法。</p>
 */
public class McpStdioClient implements AutoCloseable
{
    private final ObjectMapper json = new ObjectMapper();

    private final Process process;

    private final BufferedWriter writer;

    private final Map<Long, CompletableFuture<JsonNode>> pending = new ConcurrentHashMap<>();

    private final AtomicLong seq = new AtomicLong();

    private final int timeoutSeconds;

    private final Thread reader;

    public McpStdioClient(String command, List<String> args, String workDir, boolean inheritEnv,
            Map<String, String> env, int timeoutSeconds) throws IOException
    {
        this.timeoutSeconds = timeoutSeconds <= 0 ? 30 : timeoutSeconds;
        List<String> cmd = new ArrayList<>();
        cmd.add(command);
        if (args != null)
        {
            cmd.addAll(args);
        }
        ProcessBuilder builder = new ProcessBuilder(cmd);
        if (workDir != null && !workDir.isBlank())
        {
            builder.directory(new File(workDir));
        }
        Map<String, String> processEnv = builder.environment();
        if (!inheritEnv)
        {
            processEnv.clear();
            String[] keep = { "PATH", "SYSTEMROOT", "SYSTEMDRIVE", "WINDIR", "TEMP", "TMP", "HOME", "USERPROFILE",
                    "LANG", "LC_ALL" };
            for (String key : keep)
            {
                String value = System.getenv(key);
                if (value != null)
                {
                    processEnv.put(key, value);
                }
            }
            processEnv.put("PYTHONUTF8", "1");
        }
        if (env != null && !env.isEmpty())
        {
            processEnv.putAll(env);
        }
        builder.redirectErrorStream(false);
        this.process = builder.start();
        this.writer = new BufferedWriter(
                new OutputStreamWriter(process.getOutputStream(), StandardCharsets.UTF_8));

        Thread errReader = new Thread(this::drainError, "mcp-stderr");
        errReader.setDaemon(true);
        errReader.start();

        this.reader = new Thread(this::readLoop, "mcp-stdout");
        this.reader.setDaemon(true);
        this.reader.start();
    }

    private void drainError()
    {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getErrorStream(), StandardCharsets.UTF_8)))
        {
            while (reader.readLine() != null)
            {
                // 外部进程的 stderr 不应阻塞主流程，丢弃内容只做消费
            }
        }
        catch (IOException ignored)
        {
        }
    }

    private void readLoop()
    {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8)))
        {
            String line;
            while ((line = reader.readLine()) != null)
            {
                if (line.isBlank())
                {
                    continue;
                }
                JsonNode node = json.readTree(line);
                JsonNode id = node.get("id");
                if (id != null && id.canConvertToLong())
                {
                    CompletableFuture<JsonNode> future = pending.remove(id.asLong());
                    if (future != null)
                    {
                        future.complete(node);
                    }
                }
            }
        }
        catch (Exception ignored)
        {
        }
        finally
        {
            pending.values().forEach(f -> f.completeExceptionally(new IOException("MCP 进程已退出")));
            pending.clear();
        }
    }

    public JsonNode request(String method, JsonNode params) throws Exception
    {
        long id = seq.incrementAndGet();
        CompletableFuture<JsonNode> future = new CompletableFuture<>();
        pending.put(id, future);
        ObjectNode request = json.createObjectNode();
        request.put("jsonrpc", "2.0");
        request.put("id", id);
        request.put("method", method);
        if (params != null)
        {
            request.set("params", params);
        }
        writeLine(request);
        try
        {
            return future.get(timeoutSeconds, TimeUnit.SECONDS);
        }
        catch (TimeoutException e)
        {
            pending.remove(id);
            throw new IOException("MCP 请求超时：" + method);
        }
        finally
        {
            pending.remove(id);
        }
    }

    public void notify(String method, JsonNode params) throws IOException
    {
        ObjectNode notification = json.createObjectNode();
        notification.put("jsonrpc", "2.0");
        notification.put("method", method);
        if (params != null)
        {
            notification.set("params", params);
        }
        writeLine(notification);
    }

    private void writeLine(JsonNode node) throws IOException
    {
        synchronized (writer)
        {
            writer.write(json.writeValueAsString(node));
            writer.newLine();
            writer.flush();
        }
    }

    @Override
    public void close()
    {
        try
        {
            writer.close();
        }
        catch (IOException ignored)
        {
        }
        process.destroy();
    }
}
