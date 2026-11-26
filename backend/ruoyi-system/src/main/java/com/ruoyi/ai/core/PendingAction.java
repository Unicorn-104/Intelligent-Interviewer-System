package com.ruoyi.ai.core;

import java.io.Serializable;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 待确认动作：模型"打算做什么"的唯一载体。
 *
 * <p>业务参数放在 payload 中。payload 内是 List/Map/Long 等普通对象：
 * 内存存储时按对象引用取回；切到 Redis 时走 {@link PendingActionCodec} 的 JDK 序列化，
 * 以保留 Long 等精确类型（JSON 会把 Long 退化成 Integer）。</p>
 */
public class PendingAction implements Serializable
{
    private static final long serialVersionUID = 1L;

    public String id;

    /** 归属端，apply 时校验，防止跨端消费。 */
    public String scope;

    /** 动作类型：create / classify / undo 等，由产生它的工具自定义。 */
    public String kind;

    /** 前端确认卡片标题。 */
    public String title;

    /** 前端确认卡片摘要。 */
    public String summary;

    public String operator;

    public long expireAt;

    public final Map<String, Object> payload = new LinkedHashMap<>();

    @SuppressWarnings("unchecked")
    public <T> T get(String key)
    {
        return (T) payload.get(key);
    }

    public PendingAction put(String key, Object value)
    {
        payload.put(key, value);
        return this;
    }
}
