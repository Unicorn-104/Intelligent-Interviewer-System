package com.ruoyi.web.controller.enterprise;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import com.ruoyi.enterprise.service.ITalentPoolService;

class TalentSearchControllerTest
{
    @Test void optionalQueryFieldsBindWithoutChangingExistingRequestContract() throws Exception
    {
        var service=mock(ITalentPoolService.class);var controller=new TalentPoolController();
        ReflectionTestUtils.setField(controller,"talentPoolService",service);
        when(service.listTalents(eq(9L),eq("合成"),isNull(),isNull(),isNull(),isNull(),eq(2),eq(20),any()))
          .thenAnswer(call -> {
              TalentSearchCriteria c=call.getArgument(8);c.validate();
              assertEquals(3,c.getMinimumEducation());assertEquals("3to5",c.getExperienceRange());
              assertEquals("合成城市",c.getCity());assertEquals("current",c.getCityType());assertEquals(7,c.getLoginWithinDays());
              return List.of(Map.of("talentId",11));
          });
        try(var security=mockStatic(SecurityUtils.class)) {
            LoginUser login=new LoginUser();login.setUserId(9L);security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build().perform(get("/enterprise/talent/list")
              .param("keyword","合成").param("minimumEducation","3").param("experienceRange","3to5")
              .param("city","合成城市").param("cityType","current").param("loginWithinDays","7").param("pageNum","2"))
              .andExpect(status().isOk()).andExpect(jsonPath("$.rows[0].talentId").value(11));
        }
    }
    @Test void absentNewFiltersRemainOptionalForPcAndExistingClients() throws Exception
    {
        var service=mock(ITalentPoolService.class);var controller=new TalentPoolController();
        ReflectionTestUtils.setField(controller,"talentPoolService",service);
        when(service.listTalents(eq(9L),isNull(),isNull(),isNull(),isNull(),isNull(),eq(1),eq(20),any()))
          .thenAnswer(call -> {TalentSearchCriteria c=call.getArgument(8);assertNull(c.getMinimumEducation());
              assertNull(c.getExperienceRange());assertNull(c.getCity());assertNull(c.getLoginWithinDays());return List.of();});
        try(var security=mockStatic(SecurityUtils.class)) {
            LoginUser login=new LoginUser();login.setUserId(9L);security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build().perform(get("/enterprise/talent/list"))
              .andExpect(status().isOk()).andExpect(jsonPath("$.rows").isEmpty());
        }
    }
}
