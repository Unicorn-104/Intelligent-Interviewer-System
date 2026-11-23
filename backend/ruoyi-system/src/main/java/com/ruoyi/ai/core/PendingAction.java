package com.ruoyi.ai.core;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 待确认动作：模型"打算做什么"的唯一载体。
 *
 * <p>业务参数放在 payload 中。草稿只活在内存里、不序列化，因此 payload 可以直接放
 * List/Map 等对象引用，读取方按写入时的类型取回即可。</p>
 */
public class PendingAction
{
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
