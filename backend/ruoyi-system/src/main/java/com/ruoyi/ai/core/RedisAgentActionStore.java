package com.ruoyi.ai.core;

import java.time.Duration;
import java.util.Collections;
import java.util.UUID;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.stereotype.Component;

/**
 * Redis 版草稿暂存区，供多实例部署共享。
 *
 * <ul>
 *   <li>键 {@code ai:pending:<id>}，TTL 10 分钟，与内存版一致。</li>
 *   <li>take 用 Lua GET+DEL 原子消费，两个节点同时确认也只有一个能拿到草稿。</li>
 *   <li>启用方式：{@code ai.agent.pending.store=redis}；默认仍为内存版。</li>
 * </ul>
 */
@Component
@ConditionalOnProperty(name = "ai.agent.pending.store", havingValue = "redis")
public class RedisAgentActionStore implements AgentActionStore
{
    private static final String PREFIX = "ai:pending:";

    private static final Duration TTL = Duration.ofMinutes(10);

    private static final DefaultRedisScript<String> TAKE_SCRIPT = new DefaultRedisScript<>(
            "local v = redis.call('GET', KEYS[1]) "
                    + "if v then redis.call('DEL', KEYS[1]) end "
                    + "return v",
            String.class);

    private final StringRedisTemplate redis;

    public RedisAgentActionStore(StringRedisTemplate redis)
    {
        this.redis = redis;
    }

    @Override
    public String save(PendingAction action)
    {
        String id = UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        action.id = id;
        action.expireAt = System.currentTimeMillis() + TTL.toMillis();
        redis.opsForValue().set(PREFIX + id, PendingActionCodec.encode(action), TTL);
        return id;
    }

    @Override
    public PendingAction take(String id)
    {
        if (id == null || id.isBlank())
        {
            return null;
        }
        String text = redis.execute(TAKE_SCRIPT, Collections.singletonList(PREFIX + id.trim()));
        PendingAction action = PendingActionCodec.decode(text);
        if (action == null || action.expireAt < System.currentTimeMillis())
        {
            return null;
        }
        return action;
    }
}
