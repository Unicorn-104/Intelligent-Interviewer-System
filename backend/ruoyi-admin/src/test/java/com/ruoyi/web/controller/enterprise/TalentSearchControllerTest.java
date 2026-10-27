package com.ruoyi.web.controller.enterprise;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import com.ruoyi.enterprise.service.ITalentPoolService;
import com.ruoyi.system.domain.app.AppResumePdfDocument;

class TalentSearchControllerTest
{
    @TempDir Path tempDir;
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
    @Test void originalResumePdfIsServedInlineWithUtf8Name() throws Exception
    {
        var service=mock(ITalentPoolService.class);var controller=new TalentPoolController();
        ReflectionTestUtils.setField(controller,"talentPoolService",service);
        Path pdf=tempDir.resolve("synthetic.pdf");Files.write(pdf,new byte[]{'%','P','D','F','-',1,2,3});
        when(service.getTalentResumePdf(9L,11L))
            .thenReturn(new AppResumePdfDocument(pdf,"个人简历.pdf"));
        try(var security=mockStatic(SecurityUtils.class)) {
            LoginUser login=new LoginUser();login.setUserId(9L);security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build().perform(get("/enterprise/talent/11/resume/pdf"))
              .andExpect(status().isOk())
              .andExpect(content().contentType("application/pdf"))
              .andExpect(content().bytes(Files.readAllBytes(pdf)))
              .andExpect(header().string("Content-Disposition",
                  org.hamcrest.Matchers.containsString("inline")))
              .andExpect(header().string("Content-Disposition",
                  org.hamcrest.Matchers.containsString(
                      "filename*=UTF-8''%E4%B8%AA%E4%BA%BA%E7%AE%80%E5%8E%86.pdf")));
        }
        verify(service).getTalentResumePdf(9L,11L);
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
