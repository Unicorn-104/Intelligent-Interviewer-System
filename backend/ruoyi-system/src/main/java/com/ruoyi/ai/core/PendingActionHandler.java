package com.ruoyi.ai.core;

import java.util.Map;

/**
 * 待确认动作的执行器。通常由产生该草稿的写工具自己实现，保证"提案"与"执行"口径一致。
 */
public interface PendingActionHandler
{
    boolean supports(PendingAction action);

    /** 用户确认后真正写库，返回给前端的结果摘要。 */
    Map<String, Object> apply(PendingAction action, ToolContext ctx);
}
