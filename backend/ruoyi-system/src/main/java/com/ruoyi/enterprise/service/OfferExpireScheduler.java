package com.ruoyi.enterprise.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** 每分钟把超过回复截止时间仍未处理的 Offer 置为已过期，并收口候选人状态。 */
@Component
public class OfferExpireScheduler
{
    private static final Logger LOG = LoggerFactory.getLogger(OfferExpireScheduler.class);

    @Autowired
    private IOfferService offerService;

    @Scheduled(fixedDelay = 60_000L, initialDelay = 60_000L)
    public void expireOverdueOffers()
    {
        try
        {
            offerService.expireOverdueOffers();
        }
        catch (RuntimeException ex)
        {
            LOG.warn("Offer 过期收口失败，将在后续轮次重试；异常类型：{}", ex.getClass().getSimpleName());
        }
    }
}
