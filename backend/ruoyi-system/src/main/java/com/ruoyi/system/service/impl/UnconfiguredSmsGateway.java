package com.ruoyi.system.service.impl;

import org.springframework.stereotype.Component;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.SmsGateway;

/**
 * 短信网关默认实现：未接入供应商时统一抛出配置缺失提示。
 */
@Component
public class UnconfiguredSmsGateway implements SmsGateway
{
    @Override
    public void send(String phone, String content)
    {
        throw new ServiceException("短信服务尚未配置，请联系管理员");
    }
}
