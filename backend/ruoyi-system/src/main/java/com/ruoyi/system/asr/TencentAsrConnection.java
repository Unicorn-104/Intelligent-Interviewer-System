package com.ruoyi.system.asr;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.nio.ByteBuffer;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;

import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * 浏览器音频流与识别服务之间的桥接连接。
 *
 * 上行：浏览器 PCM 帧 -> 腾讯云 WebSocket；下行：稳定句文本 -> 回调落库并推送前端。
 */
public class TencentAsrConnection
{
    private static final Logger log = LoggerFactory.getLogger(TencentAsrConnection.class);

    private static final int MAX_PENDING_FRAMES = 100;

    private final URI uri;

    private final AsrProvider provider;

    private final Consumer<String> onFinal;

    private final Consumer<String> onError;

    private final Deque<byte[]> pending = new ArrayDeque<>();

    /** JDK WebSocket 同一时刻只允许一个未完成的发送，这里串行化 */
    private final Object sendLock = new Object();

    private final StringBuilder textBuffer = new StringBuilder();

    private volatile WebSocket socket;

    private volatile boolean open;

    private volatile boolean closing;

    private String lastFinalText;

    private long lastFinalAt;

    public TencentAsrConnection(URI uri, AsrProvider provider, Consumer<String> onFinal, Consumer<String> onError)
    {
        this.uri = uri;
        this.provider = provider;
        this.onFinal = onFinal;
        this.onError = onError;
    }

    public void connect()
    {
        HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        client.newWebSocketBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .buildAsync(uri, new Listener())
                .orTimeout(15, TimeUnit.SECONDS)
                .whenComplete((ws, error) -> {
                    if (error != null)
                    {
                        log.warn("腾讯云实时语音识别连接失败: {}", error.getMessage());
                        notifyError("语音识别服务连接失败");
                    }
                });
    }

    public void sendAudio(byte[] data)
    {
        if (data == null || data.length == 0)
        {
            return;
        }
        WebSocket ws = socket;
        if (open && ws != null && !closing)
        {
            try
            {
                synchronized (sendLock)
                {
                    ws.sendBinary(ByteBuffer.wrap(data), true);
                }
                return;
            }
            catch (Exception ignored)
            {
                // 连接已被对端关闭时转为排队，等待重连期间的剩余帧被丢弃
            }
        }
        synchronized (pending)
        {
            if (pending.size() >= MAX_PENDING_FRAMES)
            {
                pending.pollFirst();
            }
            pending.addLast(data);
        }
    }

    public void end()
    {
        if (closing)
        {
            return;
        }
        closing = true;
        WebSocket ws = socket;
        if (ws != null)
        {
            try
            {
                synchronized (sendLock)
                {
                    // 只发结束帧，等待服务端把尾句识别完再关连接
                    ws.sendText("{\"type\":\"end\"}", true);
                }
            }
            catch (Exception ignored)
            {
            }
            CompletableFuture.delayedExecutor(2, TimeUnit.SECONDS).execute(() -> {
                try
                {
                    ws.sendClose(WebSocket.NORMAL_CLOSURE, "end");
                }
                catch (Exception ignored)
                {
                }
            });
        }
        open = false;
    }

    public void abort()
    {
        closing = true;
        open = false;
        WebSocket ws = socket;
        if (ws != null)
        {
            try
            {
                ws.abort();
            }
            catch (Exception ignored)
            {
            }
        }
        synchronized (pending)
        {
            pending.clear();
        }
    }

    private void flushPending()
    {
        WebSocket ws = socket;
        if (ws == null)
        {
            return;
        }
        while (true)
        {
            byte[] frame;
            synchronized (pending)
            {
                frame = pending.pollFirst();
            }
            if (frame == null)
            {
                return;
            }
            try
            {
                synchronized (sendLock)
                {
                    ws.sendBinary(ByteBuffer.wrap(frame), true);
                }
            }
            catch (Exception e)
            {
                return;
            }
        }
    }

    private void handleText(String message)
    {
        AsrEvent event = provider.parse(message);
        if (event.getType() == AsrEvent.Type.ERROR)
        {
            log.warn("腾讯云实时语音识别返回错误: {}", event.getMessage());
            notifyError(event.getMessage());
            return;
        }
        if (event.getType() != AsrEvent.Type.FINAL || StringUtils.isBlank(event.getText()))
        {
            return;
        }
        long now = System.currentTimeMillis();
        if (event.getText().equals(lastFinalText) && now - lastFinalAt < 3000)
        {
            return;
        }
        lastFinalText = event.getText();
        lastFinalAt = now;
        log.info("实时字幕稳定句: length={}", event.getText().length());
        onFinal.accept(event.getText());
    }

    private void notifyError(String message)
    {
        if (closing)
        {
            return;
        }
        closing = true;
        open = false;
        onError.accept(StringUtils.isNotBlank(message) ? message : "语音识别服务异常");
    }

    private class Listener implements WebSocket.Listener
    {
        @Override
        public void onOpen(WebSocket webSocket)
        {
            socket = webSocket;
            open = true;
            log.info("腾讯云实时语音识别已连接");
            flushPending();
            WebSocket.Listener.super.onOpen(webSocket);
        }

        @Override
        public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last)
        {
            textBuffer.append(data);
            if (last)
            {
                String message = textBuffer.toString();
                textBuffer.setLength(0);
                handleText(message);
            }
            // JDK WebSocket 需显式请求下一条消息，否则只会收到第一条
            webSocket.request(1);
            return null;
        }

        @Override
        public CompletionStage<?> onClose(WebSocket webSocket, int statusCode, String reason)
        {
            open = false;
            socket = null;
            log.warn("腾讯云实时语音识别关闭: code={} reason={}", statusCode, reason);
            if (!closing)
            {
                notifyError("语音识别连接已关闭");
            }
            return null;
        }

        @Override
        public void onError(WebSocket webSocket, Throwable error)
        {
            open = false;
            socket = null;
            log.warn("腾讯云实时语音识别异常: {}", error.getMessage());
            notifyError("语音识别连接异常");
        }
    }
}
