package com.ruoyi.system.service.app;

import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;
import com.ruoyi.system.mapper.app.AppCompanyMapper;
import com.ruoyi.system.service.impl.EnterpriseJobServiceImpl;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class CompanyPublicationTest
{
    private final EnterpriseJobMapper jobs = mock(EnterpriseJobMapper.class);
    private final AppCompanyMapper companies = mock(AppCompanyMapper.class);
    private final EnterpriseJobServiceImpl service = new EnterpriseJobServiceImpl();

    @BeforeEach
    void setup()
    {
        DashboardMapper dashboard = mock(DashboardMapper.class);
        when(dashboard.selectCompanyIdByUser(17L)).thenReturn(7L);
        ReflectionTestUtils.setField(service, "jobMapper", jobs);
        ReflectionTestUtils.setField(service, "dashboardMapper", dashboard);
        ReflectionTestUtils.setField(service, "companyMapper", companies);
        when(companies.selectLastInsertedPositionId()).thenReturn(99L);
    }

    @Test
    void creatingPublishedJobNotifiesButDraftDoesNot()
    {
        service.createJob(17L, Map.of("title", "Synthetic job", "status", 0));
        verify(companies, never()).notifyFollowers(anyLong(), anyLong());
        service.createJob(17L, Map.of("title", "Synthetic job", "status", 1));
        verify(companies).notifyFollowers(7L, 99L);
    }

    @Test
    void publishingOnlyNotifiesOnAnOwnedTransitionIntoPublished()
    {
        when(jobs.updateJobStatus(99L, 7L, 1)).thenReturn(1);
        when(companies.lockPositionStatus(7L, 99L)).thenReturn(0);
        service.changeJobStatus(17L, 99L, 1);
        verify(companies).notifyFollowers(7L, 99L);
        clearInvocations(companies);
        when(companies.lockPositionStatus(7L, 99L)).thenReturn(1);
        service.changeJobStatus(17L, 99L, 1);
        verify(companies, never()).notifyFollowers(anyLong(), anyLong());
        when(companies.lockPositionStatus(7L, 99L)).thenReturn(null);
        service.changeJobStatus(17L, 99L, 1);
        verify(companies, never()).notifyFollowers(anyLong(), anyLong());
    }
}
