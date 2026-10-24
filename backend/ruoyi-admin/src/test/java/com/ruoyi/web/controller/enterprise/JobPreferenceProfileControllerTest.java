package com.ruoyi.web.controller.enterprise;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.framework.web.service.TokenService;
import com.ruoyi.system.domain.app.AppUserProfile;
import com.ruoyi.system.service.app.IAppUserProfileService;
import com.ruoyi.web.controller.app.AppUserProfileController;

class JobPreferenceProfileControllerTest
{
    @Test void salaryUpdateUsesAuthenticatedUserAndCannotWriteOtherUsersPreference() throws Exception
    {
        var controller=new AppUserProfileController();var service=mock(IAppUserProfileService.class);
        ReflectionTestUtils.setField(controller,"profileService",service);
        ReflectionTestUtils.setField(controller,"tokenService",mock(TokenService.class));
        when(service.updateProfile(any())).thenAnswer(call->{AppUserProfile p=call.getArgument(0);
            assertEquals(101L,p.getUserId());assertTrue(p.isSalaryProvided());p.validateSalary();
            assertEquals(8000,p.getSalaryMin());assertEquals(12000,p.getSalaryMax());return 1;});
        var response=new AppUserProfile();response.setUserId(101L);response.setNickName("合成用户");
        response.setSalaryMin(8000);response.setSalaryMax(12000);response.setSalaryNegotiable(0);
        when(service.selectProfileByUserId(101L)).thenReturn(response);
        try(var security=mockStatic(SecurityUtils.class))
        {
            var login=new LoginUser();login.setUserId(101L);login.setUser(new SysUser());
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            security.when(SecurityUtils::getUsername).thenReturn("synthetic");
            MockMvcBuilders.standaloneSetup(controller).build().perform(put("/app/profile").contentType("application/json")
                .content("{\"userId\":999,\"nickName\":\"合成用户\",\"salaryMin\":8000,\"salaryMax\":12000,\"salaryNegotiable\":0}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.userId").value(101))
                .andExpect(jsonPath("$.data.salaryMax").value(12000)).andExpect(jsonPath("$.data.salaryProvided").doesNotExist());
            verify(service).selectProfileByUserId(101L);
        }
    }
}
