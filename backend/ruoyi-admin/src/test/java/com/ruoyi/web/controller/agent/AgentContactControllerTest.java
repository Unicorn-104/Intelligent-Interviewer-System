package com.ruoyi.web.controller.agent;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.app.AppCompanyMapper;

class AgentContactControllerTest
{
    @AfterEach
    void cleanup() { SecurityContextHolder.clearContext(); }

    @Test
    void anonymousRequestsCannotQueryRecruiterData()
    {
        SecurityContextHolder.clearContext();
        var mapper = mock(AppCompanyMapper.class);
        var controller = new AgentContactController();
        ReflectionTestUtils.setField(controller, "companies", mapper);
        assertThrows(ServiceException.class, () -> controller.detail(20L));
        verifyNoInteractions(mapper);
    }

    @Test
    void loggedInUsersGetRealPublicFieldsAndMissingContactDoesNotFallback()
    {
        var login = new LoginUser(17L, 1L, new SysUser(), Set.of());
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(login, null, Set.of()));
        var mapper = mock(AppCompanyMapper.class);
        var controller = new AgentContactController();
        ReflectionTestUtils.setField(controller, "companies", mapper);
        var contact = Map.<String, Object>of("id", 20L, "name", "合成 HR", "companyId", 3L, "companyName", "合成企业");
        when(mapper.selectRecruiter(20L)).thenReturn(contact);
        assertEquals(contact, controller.detail(20L).get("data"));
        assertThrows(ServiceException.class, () -> controller.detail(999L));
    }
}
