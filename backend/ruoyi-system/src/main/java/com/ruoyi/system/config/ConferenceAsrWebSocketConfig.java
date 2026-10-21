package com.ruoyi.system.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

import com.ruoyi.system.asr.ConferenceAsrWebSocketHandler;

/**
 * 实时字幕 WebSocket 端点注册。
 */
@Configuration
@EnableWebSocket
public class ConferenceAsrWebSocketConfig implements WebSocketConfigurer
{
    private final ConferenceAsrWebSocketHandler handler;

    public ConferenceAsrWebSocketConfig(ConferenceAsrWebSocketHandler handler)
    {
        this.handler = handler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry)
    {
        registry.addHandler(handler, "/ws/conference-asr").setAllowedOriginPatterns("*");
    }
}
