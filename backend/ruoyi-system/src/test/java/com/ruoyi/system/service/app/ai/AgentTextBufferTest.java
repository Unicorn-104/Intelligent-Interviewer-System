package com.ruoyi.system.service.app.ai;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class AgentTextBufferTest
{
    @Test
    void combinesSmallModelChunksAndFlushesFinalTailWithoutLoss()
    {
        List<String> chunks = new ArrayList<>();
        AgentTextBuffer buffer = new AgentTextBuffer(chunks::add, () -> 0L);
        for (int index = 0; index < 795; index++) buffer.accept("文");
        assertEquals(1, chunks.size());
        buffer.flush();
        buffer.flush();
        assertEquals(2, chunks.size());
        assertEquals("文".repeat(795), String.join("", chunks));
    }

    @Test
    void flushesProgressEveryHalfSecondWithoutWritingEveryToken()
    {
        AtomicLong clock = new AtomicLong();
        List<String> chunks = new ArrayList<>();
        AgentTextBuffer buffer = new AgentTextBuffer(chunks::add, clock::get);
        buffer.accept("第一段");
        clock.set(TimeUnit.MILLISECONDS.toNanos(499));
        buffer.accept("第二段");
        assertTrue(chunks.isEmpty());
        clock.set(TimeUnit.MILLISECONDS.toNanos(500));
        buffer.accept("第三段");
        assertEquals(List.of("第一段第二段第三段"), chunks);
        clock.set(TimeUnit.MILLISECONDS.toNanos(999));
        buffer.accept("尾段");
        assertEquals(1, chunks.size());
        buffer.flush();
        assertEquals(List.of("第一段第二段第三段", "尾段"), chunks);
    }

    @Test
    void emptyFlushDoesNotTouchDatabaseAndPublishFailureIsNotSwallowed()
    {
        AgentTextBuffer buffer = new AgentTextBuffer(text -> {
            throw new IllegalStateException("synthetic persistence failure");
        }, () -> 0L);
        assertDoesNotThrow(buffer::flush);
        buffer.accept("synthetic unfinished answer");
        assertThrows(IllegalStateException.class, buffer::flush);
    }
}
