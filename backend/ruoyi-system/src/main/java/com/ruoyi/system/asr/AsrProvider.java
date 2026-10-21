package com.ruoyi.system.asr;

import java.net.URI;

/**
 * 语音识别提供方抽象，替换厂商时只需新增实现并调整 app.asr.provider。
 */
public interface AsrProvider
{
    /**
     * 提供方名称，与 app.asr.provider 对应。
     */
    String name();

    /**
     * 当前提供方是否具备可用凭证。
     */
    boolean isConfigured();

    /**
     * 生成一次性识别流地址。
     */
    URI buildStreamUri(AsrStreamContext context);

    /**
     * 解析提供方返回的消息。
     */
    AsrEvent parse(String message);
}
