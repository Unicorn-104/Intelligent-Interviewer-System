package com.ruoyi.web.controller.enterprise;

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
import com.ruoyi.enterprise.service.RescheduleRequestService;
import com.ruoyi.web.controller.candidate.CandidateRescheduleRequestController;

class RescheduleReviewControllerTest
{
    @Test void listUsesAuthenticatedEnterpriseUserAndServerPagination() throws Exception
    {
        var service = mock(RescheduleRequestService.class);
        var controller = new RescheduleReviewController();
        ReflectionTestUtils.setField(controller,"requestService",service);
        when(service.list(9L,"pending",2,20)).thenReturn(List.of(Map.of("requestId",11,"status","pending")));
        try (var security = mockStatic(SecurityUtils.class))
        {
            var login = new LoginUser(); login.setUserId(9L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build()
                .perform(get("/enterprise/interview/reschedule-requests").param("status","pending")
                    .param("pageNum","2").param("companyId","999"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.rows[0].requestId").value(11));
            verify(service).list(9L,"pending",2,20);
        }
    }
    @Test void reviewUsesRequestIdAndDoesNotDelegateToDirectRescheduleEndpoint() throws Exception
    {
        var service = mock(RescheduleRequestService.class);
        var controller = new RescheduleReviewController();
        ReflectionTestUtils.setField(controller,"requestService",service);
        when(service.review(9L,11L,"approved","合成说明")).thenReturn(Map.of("requestId",11,"status","approved"));
        try (var security = mockStatic(SecurityUtils.class))
        {
            var login = new LoginUser(); login.setUserId(9L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            MockMvcBuilders.standaloneSetup(controller).build()
                .perform(put("/enterprise/interview/reschedule-requests/11/review")
                    .contentType("application/json").content("{\"decision\":\"approved\",\"note\":\"合成说明\",\"reviewerId\":\"999\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.status").value("approved"));
            verify(service).review(9L,11L,"approved","合成说明");
        }
    }
    @Test void candidateSubmissionCannotChooseAnotherUserOrCompany() throws Exception
    {
        var service = mock(RescheduleRequestService.class);
        var controller = new CandidateRescheduleRequestController();
        ReflectionTestUtils.setField(controller,"requestService",service);
        when(service.submit(101L,21L,"2099-01-03 09:00","合成申请原因"))
                .thenReturn(Map.of("requestId",11,"status","pending"));
        try (var security = mockStatic(SecurityUtils.class))
        {
            var login = new LoginUser(); login.setUserId(101L);
            security.when(SecurityUtils::getLoginUser).thenReturn(login);
            var mvc = MockMvcBuilders.standaloneSetup(controller).build();
            mvc.perform(post("/candidate/interview/reschedule-requests/21")
                    .contentType("application/json").content("{\"newStartTime\":\"2099-01-03 09:00\",\"reason\":\"合成申请原因\",\"candidateId\":\"999\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.status").value("pending"));
            mvc.perform(get("/candidate/interview/reschedule-requests"))
                .andExpect(status().isOk());
            verify(service).submit(101L,21L,"2099-01-03 09:00","合成申请原因");
            verify(service).own(101L,1,20);
        }
    }
}
