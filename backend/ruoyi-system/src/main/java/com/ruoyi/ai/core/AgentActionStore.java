package com.ruoyi.ai.core;

/**
 * 待确认动作暂存区。写工具只登记草稿，用户确认后由 apply 端点一次性消费。
 */
public interface AgentActionStore
{
    /** 登记草稿并返回 pendingId。 */
    String save(PendingAction action);

    /** 取出并删除；不存在或已过期返回 null。一次性消费，保证重放不会二次落库。 */
    PendingAction take(String id);

    default boolean discard(String id)
    {
        return take(id) != null;
    }
}
