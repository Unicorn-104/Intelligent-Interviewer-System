package com.ruoyi.system.service.conference;

import com.ruoyi.system.event.InterviewSessionCreatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 纯AI 场次创建事件的异步监听：事务提交后再提交线程池生成题目，避免阻塞建场响应。
 *
 * @author ruoyi
 */
@Component
public class InterviewOutlineListener
{
    private static final Logger log = LoggerFactory.getLogger(InterviewOutlineListener.class);

    @Autowired
    private InterviewOutlineService outlineService;

    @Autowired
    @Qualifier("threadPoolTaskExecutor")
    private ThreadPoolTaskExecutor executor;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onSessionCreated(InterviewSessionCreatedEvent event)
    {
        if (event == null || event.getSessionId() == null)
        {
            return;
        }
        try
        {
            executor.execute(() -> outlineService.ensureQuestions(event.getSessionId()));
        }
        catch (Exception error)
        {
            log.warn("自动出题任务提交失败，sessionId={}", event.getSessionId());
        }
    }
}
