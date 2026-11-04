package com.ruoyi.enterprise.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** 每分钟结算到期笔试记录：已开考未交卷自动交卷判分，未开考按缺考收口。 */
@Component
public class ExamSettlementScheduler
{
    private static final Logger LOG = LoggerFactory.getLogger(ExamSettlementScheduler.class);

    @Autowired
    private ICandidateExamService candidateExamService;

    @Scheduled(fixedDelay = 60_000L, initialDelay = 60_000L)
    public void settleExpiredExams()
    {
        try
        {
            int settled = candidateExamService.settleExpiredRecords();
            if (settled > 0)
            {
                LOG.info("笔试到期结算完成，本轮处理 {} 条记录", settled);
            }
        }
        catch (RuntimeException ex)
        {
            LOG.warn("笔试到期结算失败，将在后续轮次重试；异常类型：{}", ex.getClass().getSimpleName());
        }
    }
}
