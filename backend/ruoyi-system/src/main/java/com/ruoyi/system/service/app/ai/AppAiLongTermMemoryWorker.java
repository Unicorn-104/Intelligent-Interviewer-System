package com.ruoyi.system.service.app.ai;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Processes durable MySQL extraction and Qdrant synchronization jobs. */
@Component
public class AppAiLongTermMemoryWorker
{
    private final AppAiLongTermMemoryService memory;

    public AppAiLongTermMemoryWorker(AppAiLongTermMemoryService memory) { this.memory = memory; }

    @Scheduled(fixedDelayString = "${app.ai.memory.worker-delay-ms:2000}", initialDelayString = "${app.ai.memory.worker-delay-ms:2000}")
    public void process() { memory.processJobsSafely(); }
}
