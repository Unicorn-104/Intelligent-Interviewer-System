package com.ruoyi.web.controller.enterprise;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import com.ruoyi.enterprise.service.TalentDiscoveryService;

class TalentDiscoveryControllerTest
{
    @Test void platformListBindsSeekingStatusAndFiltersWithoutEnterpriseIdParameter() throws Exception
    {
        var service=mock(TalentDiscoveryService.class);var controller=new TalentDiscoveryController();
        ReflectionTestUtils.setField(controller,"discoveryService",service);
        when(service.list(eq(9L),eq("Java"),isNull(),eq(2),eq(2),eq(20),any())).thenAnswer(call->{
            TalentSearchCriteria criteria=call.getArgument(6);criteria.validate();
            assertEquals(3,criteria.getMinimumEducation());assertEquals("target",criteria.getCityType());
            assertEquals("合成上海",criteria.getCity());
            return List.of(Map.of("userId",101,"directoryVersion",1,"name","合成未投递用户"));
        });
        try(var security=mockStatic(SecurityUtils.class))
        {
            var login=new LoginUser();login.setUserId(9L);security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build().perform(get("/enterprise/talent-discovery")
                .param("keyword","Java").param("currentStatus","2").param("pageNum","2")
                .param("minimumEducation","3").param("city","合成上海").param("companyId","999"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.rows[0].userId").value(101))
                .andExpect(jsonPath("$.rows[0].talentId").doesNotExist());
        }
    }
    @Test void detailAndOptionsUseLoggedInViewerAndRegisteredUserIdentity() throws Exception
    {
        var service=mock(TalentDiscoveryService.class);var controller=new TalentDiscoveryController();
        ReflectionTestUtils.setField(controller,"discoveryService",service);
        when(service.detail(9L,101L)).thenReturn(Map.of("userId",101,"name","合成注册用户","directoryVersion",1));
        when(service.options(9L)).thenReturn(Map.of("directions",List.of("Java"),"directoryVersion",1));
        try(var security=mockStatic(SecurityUtils.class))
        {
            var login=new LoginUser();login.setUserId(9L);security.when(SecurityUtils::getLoginUser).thenReturn(login);
            var mvc=MockMvcBuilders.standaloneSetup(controller).build();
            mvc.perform(get("/enterprise/talent-discovery/101")).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.userId").value(101)).andExpect(jsonPath("$.data.matchedScore").doesNotExist());
            mvc.perform(get("/enterprise/talent-discovery/options")).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.directoryVersion").value(1));
            verify(service).detail(9L,101L);verify(service).options(9L);
        }
    }
}
