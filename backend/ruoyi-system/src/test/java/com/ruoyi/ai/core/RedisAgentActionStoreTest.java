package com.ruoyi.ai.core;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.RedisConnection;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;

/**
 * Redis 版草稿暂存区集成测试。
 *
 * <p>本地 127.0.0.1:6379 不可用时整类跳过（assume），不会把 CI 判成失败。
 * 覆盖：TTL 写入、原子一次性消费、Long 类型保真。</p>
 */
class RedisAgentActionStoreTest
{
    private static LettuceConnectionFactory factory;

    private RedisAgentActionStore store;

    @BeforeAll
    static void connect()
    {
        try
        {
            LettuceConnectionFactory candidate = new LettuceConnectionFactory("127.0.0.1", 6379);
            candidate.afterPropertiesSet();
            try (RedisConnection connection = candidate.getConnection())
            {
                connection.ping();
            }
            factory = candidate;
        }
        catch (Exception e)
        {
            factory = null;
        }
    }

    @BeforeEach
    void setup()
    {
        Assumptions.assumeTrue(factory != null, "本地 Redis 不可用，跳过集成测试");
        store = new RedisAgentActionStore(new StringRedisTemplate(factory));
    }

    @Test
    void saveThenTakeOnceKeepsTypes()
    {
        PendingAction action = new PendingAction()
                .put("ids", List.of(11L, 22L))
                .put("companyId", 81L);
        action.scope = "admin";
        action.kind = "delete";

        String id = store.save(action);
        assertNotNull(id);

        StringRedisTemplate redis = new StringRedisTemplate(factory);
        Long ttl = redis.getExpire("ai:pending:" + id);
        assertTrue(ttl != null && ttl > 0 && ttl <= 600, "TTL 应为 10 分钟内");

        PendingAction back = store.take(id);
        assertNotNull(back);
        assertEquals("delete", back.kind);
        assertEquals(List.of(11L, 22L), back.get("ids"));
        assertEquals(81L, ((Number) back.get("companyId")).longValue());

        assertNull(store.take(id), "同一草稿只能消费一次");
    }
}
