package com.ruoyi.system.asr;

/**
 * 建立识别流时需要的上下文。
 */
public class AsrStreamContext
{
    private final Long sessionId;

    private final String role;

    public AsrStreamContext(Long sessionId, String role)
    {
        this.sessionId = sessionId;
        this.role = role;
    }

    public Long getSessionId()
    {
        return sessionId;
    }

    public String getRole()
    {
        return role;
    }
}
