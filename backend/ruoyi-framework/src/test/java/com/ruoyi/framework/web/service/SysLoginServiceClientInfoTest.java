package com.ruoyi.framework.web.service;

import com.ruoyi.common.utils.http.UserAgentUtils;
import jakarta.annotation.PostConstruct;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mockStatic;

class SysLoginServiceClientInfoTest
{
    @Test
    void initializesClientParserDuringBeanStartupInsteadOfFirstLogin() throws Exception
    {
        assertTrue(SysLoginService.class.getMethod("initializeClientInfo").isAnnotationPresent(PostConstruct.class));
        try (MockedStatic<UserAgentUtils> parser = mockStatic(UserAgentUtils.class))
        {
            new SysLoginService().initializeClientInfo();
            parser.verify(() -> UserAgentUtils.getBrowser(anyString()));
            parser.verify(() -> UserAgentUtils.getOperatingSystem(anyString()));
            parser.verifyNoMoreInteractions();
        }
    }
}
