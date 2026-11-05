package com.ruoyi.system.service.report;

import com.ruoyi.system.config.InterviewReportProperties;
import com.ruoyi.system.event.InterviewFinishedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 面试结束事件的异步监听：事务提交后再提交到线程池，避免阻塞结束响应，
 * 也避免事务回滚时留下孤儿生成任务。
 *
 * @author ruoyi
 */
@Component
public class InterviewReportListener
{
    private static final Logger log = LoggerFactory.getLogger(InterviewReportListener.class);

    @Autowired
    private InterviewReportGenerator generator;

    @Autowired
    private InterviewReportProperties properties;

    @Autowired
    @Qualifier("threadPoolTaskExecutor")
    private ThreadPoolTaskExecutor executor;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onInterviewFinished(InterviewFinishedEvent event)
    {
        if (event == null || event.getSessionId() == null || !properties.isEnabled())
        {
            return;
        }
        try
        {
            executor.execute(() -> generator.generate(event.getSessionId()));
        }
        catch (Exception error)
        {
            log.warn("面试报告任务提交失败，sessionId={}", event.getSessionId());
        }
    }
}
