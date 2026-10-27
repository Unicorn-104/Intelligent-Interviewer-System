package com.ruoyi.enterprise.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.ruoyi.enterprise.mapper.EnterpriseSystemNoticeMapper;

/** 每轮最多100位账号，按账号游标轮转；通过事务服务去重。 */
@Component
public class EnterpriseSystemNoticeScheduler
{
    private static final Logger LOG=LoggerFactory.getLogger(EnterpriseSystemNoticeScheduler.class);
    @Autowired private EnterpriseSystemNoticeMapper mapper;
    @Autowired private EnterpriseSystemNoticeService notices;
    private long afterId;

    @Scheduled(fixedDelay=60000,initialDelay=30000)
    public void refresh()
    {
        var users=mapper.recipients(afterId);
        if(users.isEmpty()){afterId=0;return;}
        for(Long user:users)
        {
            try {notices.refresh(user);}
            catch(RuntimeException ex){LOG.warn("系统通知同步失败，账号将在后续轮次重试；异常类型：{}",ex.getClass().getSimpleName());}
            afterId=user;
        }
        if(users.size()<100) afterId=0;
    }
}
