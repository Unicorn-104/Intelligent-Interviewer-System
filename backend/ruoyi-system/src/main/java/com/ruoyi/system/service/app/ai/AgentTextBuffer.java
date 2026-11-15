package com.ruoyi.system.service.app.ai;

import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import java.util.function.LongSupplier;

final class AgentTextBuffer implements Consumer<String>
{
    private final StringBuilder pending = new StringBuilder();
    private final Consumer<String> publish;
    private final LongSupplier clock;
    private long lastFlush;

    AgentTextBuffer(Consumer<String> publish, LongSupplier clock)
    {
        this.publish = publish;
        this.clock = clock;
        this.lastFlush = clock.getAsLong();
    }

    @Override
    public void accept(String text)
    {
        pending.append(text);
        if (pending.length() >= 512 || clock.getAsLong() - lastFlush >= TimeUnit.MILLISECONDS.toNanos(500))
            flush();
    }

    void flush()
    {
        if (pending.isEmpty()) return;
        publish.accept(pending.toString());
        pending.setLength(0);
        lastFlush = clock.getAsLong();
    }
}
