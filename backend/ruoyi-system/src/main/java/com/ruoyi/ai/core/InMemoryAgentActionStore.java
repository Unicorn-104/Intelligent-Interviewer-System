package com.ruoyi.ai.core;

import java.util.Comparator;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 内存版草稿暂存区。
 *
 * <ul>
 *   <li>不新建表：进程重启草稿即失效，符合"未确认即未生效"的语义。</li>
 *   <li>一次性消费：take() 取出即删除，同一 pendingId 重放不会二次落库。</li>
 *   <li>TTL 10 分钟、容量 100，超限淘汰最早过期的一条。</li>
 * </ul>
 *
 * <p>默认实现，适合单实例。多实例部署把 {@code ai.agent.pending.store} 设置为 {@code redis}，
 * 由 {@link RedisAgentActionStore} 接管，避免 apply 落到没有草稿的节点。</p>
 */
@Component
@ConditionalOnProperty(name = "ai.agent.pending.store", havingValue = "memory", matchIfMissing = true)
public class InMemoryAgentActionStore implements AgentActionStore
{
    private static final long TTL_MS = 10 * 60 * 1000L;
    private static final int MAX_SIZE = 100;

    private final Map<String, PendingAction> map = new ConcurrentHashMap<>();

    @Override
    public String save(PendingAction action)
    {
        purgeExpired();
        if (map.size() >= MAX_SIZE)
        {
            map.entrySet().stream()
                    .min(Comparator.comparingLong(e -> e.getValue().expireAt))
                    .ifPresent(e -> map.remove(e.getKey()));
        }
        String id = UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        action.id = id;
        action.expireAt = System.currentTimeMillis() + TTL_MS;
        map.put(id, action);
        return id;
    }

    @Override
    public PendingAction take(String id)
    {
        if (id == null || id.isBlank())
        {
            return null;
        }
        purgeExpired();
        PendingAction action = map.remove(id.trim());
        if (action == null || action.expireAt < System.currentTimeMillis())
        {
            return null;
        }
        return action;
    }

    private void purgeExpired()
    {
        long now = System.currentTimeMillis();
        map.entrySet().removeIf(e -> e.getValue().expireAt < now);
    }
}
