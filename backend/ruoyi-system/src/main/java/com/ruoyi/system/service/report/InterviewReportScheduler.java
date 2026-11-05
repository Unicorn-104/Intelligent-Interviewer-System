package com.ruoyi.system.service.report;

import java.util.List;
import com.ruoyi.system.config.InterviewReportProperties;
import com.ruoyi.system.mapper.InterviewReportMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.stereotype.Component;

/**
 * 报告生成补偿任务：覆盖事件丢失、进程重启、生成中超时与失败未达上限的场次。
 * 只扫描最近 scanDays 天内正常结束的面试，每次最多投递 5 场，避免触发风暴。
 *
 * @author ruoyi
 */
@Component
public class InterviewReportScheduler
{
    private static final Logger log = LoggerFactory.getLogger(InterviewReportScheduler.class);

    @Autowired
    private InterviewReportMapper reportMapper;

    @Autowired
    private InterviewReportGenerator generator;

    @Autowired
    private InterviewReportProperties properties;

    @Autowired
    @Qualifier("threadPoolTaskExecutor")
    private ThreadPoolTaskExecutor executor;

    @Scheduled(fixedDelay = 60000, initialDelay = 30000)
    public void compensate()
    {
        if (!properties.isEnabled())
        {
            return;
        }
        try
        {
            List<Long> sessionIds = reportMapper.selectRetryCandidates(properties.getScanDays(),
                    properties.getRetryWindowMinutes(), properties.getMaxRetry());
            for (Long sessionId : sessionIds)
            {
                executor.execute(() -> generator.generate(sessionId));
            }
        }
        catch (Exception error)
        {
            log.warn("面试报告补偿扫描异常");
        }
    }
}
