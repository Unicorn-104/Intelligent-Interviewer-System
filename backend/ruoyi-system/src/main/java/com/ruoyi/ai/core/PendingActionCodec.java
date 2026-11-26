package com.ruoyi.ai.core;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.util.Base64;

/**
 * 待确认草稿的序列化编解码。
 *
 * <p>用 JDK 序列化而不是 JSON：payload 里有 {@code List<Long>}、嵌套 Map 等结构，
 * JSON 反序列化会把 Long 变成 Integer，apply 时强转会遇到 ClassCastException。
 * 草稿 TTL 只有 10 分钟，版本兼容压力小；旧版本残留值解码失败按"已过期"处理。</p>
 *
 * <p>只反序列化本系统自己写进 Redis 的值，不接受外部输入。</p>
 */
public final class PendingActionCodec
{
    private PendingActionCodec()
    {
    }

    public static String encode(PendingAction action)
    {
        try (ByteArrayOutputStream bytes = new ByteArrayOutputStream();
                ObjectOutputStream out = new ObjectOutputStream(bytes))
        {
            out.writeObject(action);
            out.flush();
            return Base64.getEncoder().encodeToString(bytes.toByteArray());
        }
        catch (Exception e)
        {
            throw new IllegalStateException("草稿序列化失败", e);
        }
    }

    /** 解码失败或类型不符返回 null，调用方按"草稿已过期"处理。 */
    public static PendingAction decode(String text)
    {
        if (text == null || text.isEmpty())
        {
            return null;
        }
        try (ObjectInputStream in = new ObjectInputStream(
                new ByteArrayInputStream(Base64.getDecoder().decode(text))))
        {
            Object value = in.readObject();
            return value instanceof PendingAction ? (PendingAction) value : null;
        }
        catch (Exception e)
        {
            return null;
        }
    }
}
