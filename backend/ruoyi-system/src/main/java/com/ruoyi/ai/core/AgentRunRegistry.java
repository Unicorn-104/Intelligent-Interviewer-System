package com.ruoyi.ai.core;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

import org.springframework.stereotype.Component;

/**
 * 助手运行登记表：前端点"停止"时置取消标记并中断上游模型请求。
 *
 * <ul>
 *   <li>取消必须命中正在流式输出的那个 JVM，因此只做内存实现（单实例部署）。</li>
 *   <li>每个流式请求生成一个 runId，先于正文以 SSE {@code event: run} 下发给前端。</li>
 *   <li>请求结束在 finally 注销，避免长时间运行后 Map 泄漏。</li>
 * </ul>
 */
@Component
public class AgentRunRegistry
{
    /** 一次流式请求的句柄：取消标记 + 绑定的中断动作。 */
    public static final class Handle
    {
        public final String id;

        private final AtomicBoolean cancelled = new AtomicBoolean(false);

        private volatile Runnable cancelAction;

        Handle(String id)
        {
            this.id = id;
        }

        public boolean isCancelled()
        {
            return cancelled.get();
        }

        /** 绑定中断动作（取消 Future / 关闭流）；若绑定前已被取消则立即执行，避免取消信号丢失。 */
        public void onCancel(Runnable action)
        {
            this.cancelAction = action;
            if (cancelled.get())
            {
                action.run();
            }
        }

        boolean markCancelled()
        {
            if (!cancelled.compareAndSet(false, true))
            {
                return false;
            }
            Runnable r = cancelAction;
            if (r != null)
            {
                r.run();
            }
            return true;
        }
    }

    private final ConcurrentHashMap<String, Handle> runs = new ConcurrentHashMap<>();

    public Handle register(String id)
    {
        Handle h = new Handle(id);
        runs.put(id, h);
        return h;
    }

    /** 置取消标记并执行中断动作；返回 false 表示 runId 不存在或已取消（幂等）。 */
    public boolean cancel(String id)
    {
        Handle h = runs.get(id);
        return h != null && h.markCancelled();
    }

    public void unregister(String id)
    {
        runs.remove(id);
    }
}
