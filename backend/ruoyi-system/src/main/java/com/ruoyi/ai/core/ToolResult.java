package com.ruoyi.ai.core;

/**
 * 工具执行结果。
 *
 * <p>两种形态：只读结果（只有给模型看的文本）；写提案（文本 + 待确认草稿）。
 * 写提案不会产生任何业务副作用，真正写入发生在用户确认之后。</p>
 */
public final class ToolResult
{
    private final String text;

    private final PendingAction pending;

    private ToolResult(String text, PendingAction pending)
    {
        this.text = text == null ? "" : text;
        this.pending = pending;
    }

    public static ToolResult read(String text)
    {
        return new ToolResult(text, null);
    }

    public static ToolResult propose(String text, PendingAction pending)
    {
        if (pending == null)
        {
            throw new IllegalArgumentException("写提案必须携带待确认草稿");
        }
        return new ToolResult(text, pending);
    }

    public String getText()
    {
        return text;
    }

    public PendingAction getPending()
    {
        return pending;
    }

    public boolean hasPending()
    {
        return pending != null;
    }
}
