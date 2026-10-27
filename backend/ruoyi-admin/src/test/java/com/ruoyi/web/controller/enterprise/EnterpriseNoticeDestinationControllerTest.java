package com.ruoyi.web.controller.enterprise;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.EnterpriseNoticeDestinationService;
class EnterpriseNoticeDestinationControllerTest {
    @Test void resolveUsesLoginUserAndNoticeIdRatherThanCallerSuppliedCompany() throws Exception {
        var service=mock(EnterpriseNoticeDestinationService.class);var controller=new EnterpriseNoticeDestinationController();
        ReflectionTestUtils.setField(controller,"destinations",service);
        when(service.resolve(9L,31L)).thenReturn(Map.of("kind","candidate","messageId",31L,"candidateId",11L,"positionId",7L));
        try(var auth=mockStatic(SecurityUtils.class)) {
            var login=new LoginUser();login.setUserId(9L);auth.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build()
              .perform(get("/enterprise/system-notices/31/destination").param("companyId","999").param("userId","999"))
              .andExpect(status().isOk()).andExpect(jsonPath("$.data.kind").value("candidate"));
            verify(service).resolve(9L,31L);
        }
    }
}
