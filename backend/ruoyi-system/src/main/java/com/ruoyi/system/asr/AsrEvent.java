package com.ruoyi.system.asr;

/**
 * 识别服务返回的归一化事件，屏蔽不同厂商的协议差异。
 */
public class AsrEvent
{
    public enum Type
    {
        NONE, FINAL, ERROR
    }

    private final Type type;

    private final String text;

    private final String message;

    private AsrEvent(Type type, String text, String message)
    {
        this.type = type;
        this.text = text;
        this.message = message;
    }

    public static AsrEvent none()
    {
        return new AsrEvent(Type.NONE, null, null);
    }

    public static AsrEvent finalText(String text)
    {
        return new AsrEvent(Type.FINAL, text, null);
    }

    public static AsrEvent error(String message)
    {
        return new AsrEvent(Type.ERROR, null, message);
    }

    public Type getType()
    {
        return type;
    }

    public String getText()
    {
        return text;
    }

    public String getMessage()
    {
        return message;
    }
}
