package com.ruoyi.system.service.app;

import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.Company;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.mapper.app.AppCompanyMapper;
import com.ruoyi.system.mapper.app.AppMessageMapper;
import com.ruoyi.system.service.agent.IAgentJobService;
import com.ruoyi.system.service.app.impl.AppCompanyServiceImpl;
import com.ruoyi.system.service.app.impl.AppMessageServiceImpl;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class AppCompanyServiceTest
{
    private final IAgentJobService jobs = mock(IAgentJobService.class);
    private final AppCompanyMapper mapper = mock(AppCompanyMapper.class);
    private final AppCompanyServiceImpl service = new AppCompanyServiceImpl();
    private Company company;

    @BeforeEach
    void setup()
    {
        ReflectionTestUtils.setField(service, "jobService", jobs);
        ReflectionTestUtils.setField(service, "companyMapper", mapper);
        company = new Company();
        company.setCmpId(7L);
        company.setCmpName("Synthetic Company");
        company.setCmpStatus(1);
        company.setCmpVerifyStatus(1);
        company.setCmpCreditCode("NOT-PUBLIC");
        company.setCmpVerifyBy(999L);
        when(mapper.selectPublicCompany(7L)).thenReturn(company);
    }

    @Test
    void exposesPublicFieldsAndUsesCurrentUsersFavoriteState()
    {
        when(mapper.isFollowed(17L, 7L)).thenReturn(true);
        Map<String, Object> result = service.selectCompany(17L, 7L);
        assertEquals("Synthetic Company", result.get("name"));
        assertEquals(true, result.get("verified"));
        assertEquals(true, result.get("followed"));
        assertFalse(result.containsKey("cmpCreditCode"));
        assertFalse(result.containsKey("cmpVerifyBy"));
        assertFalse(result.containsKey("apiQuota"));
        assertEquals(false, service.selectCompany(18L, 7L).get("followed"));
    }

    @Test
    void rejectsMissingAndDisabledCompaniesBeforeFollowOrJobQuery()
    {
        assertThrows(ServiceException.class, () -> service.setFollowed(17L, 8L, true));
        company.setCmpStatus(0);
        assertThrows(ServiceException.class, () -> service.selectJobs(17L, 7L, 1, 10));
        verifyNoInteractions(jobs);
        verify(mapper, never()).follow(anyLong(), anyLong());
    }

    @Test
    void scopesExistingJobServiceByCompanyAndPreservesPaging()
    {
        service.selectJobs(17L, 7L, 2, 10);
        verify(jobs).selectJobs(argThat((AgentJobQuery query) ->
                query.getCompanyId().equals(7L) && query.getPage() == 2 && query.getSize() == 10), eq(17L));
    }

    @Test
    void unfollowAlsoClearsOnlyThisUsersOldCompanyReminders()
    {
        assertFalse(service.setFollowed(17L, 7L, false));
        verify(mapper).unfollow(17L, 7L);
        verify(mapper).markNotificationsRead(17L, 7L);
    }

    @Test
    void companyReadDelegatesWithUserAndInterestIdRatherThanCompanyId()
    {
        AppMessageMapper messages = mock(AppMessageMapper.class);
        AppMessageServiceImpl messageService = new AppMessageServiceImpl();
        ReflectionTestUtils.setField(messageService, "messageMapper", messages);
        messageService.markRead(17L, "COMPANY", 73L);
        verify(messages).markCompanyMessagesRead(17L, 73L);
    }
}
