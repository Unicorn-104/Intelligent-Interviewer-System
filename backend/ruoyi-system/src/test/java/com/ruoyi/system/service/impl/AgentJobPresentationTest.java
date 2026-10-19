package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.math.BigDecimal;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.mapper.agent.AgentJobMapper;
import com.ruoyi.system.service.impl.agent.AgentJobServiceImpl;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

class AgentJobPresentationTest
{
    @Test
    void publishedMonthlyYuanSalaryIsDisplayedInThousands()
    {
        AgentJobMapper mapper = mock(AgentJobMapper.class);
        AgentJobServiceImpl service = new AgentJobServiceImpl();
        ReflectionTestUtils.setField(service, "jobMapper", mapper);
        AgentJob job = new AgentJob();
        job.setSalaryMin(new BigDecimal("15000.50"));
        job.setSalaryMax(new BigDecimal("25000"));
        job.setEducationRequired(1);
        when(mapper.selectJobById(42L, 100L)).thenReturn(job);
        assertEquals("15.0005-25K", service.selectJob(42L, 100L).getSalaryText());
        assertEquals("中专", job.getEducationText());
        job.setSalaryMin(null);
        assertEquals("25K以下", service.selectJob(42L, 100L).getSalaryText());
        job.setSalaryMin(new BigDecimal("15000")); job.setSalaryMax(null);
        assertEquals("15K以上", service.selectJob(42L, 100L).getSalaryText());
        job.setSalaryMin(null);
        assertEquals("薪资面议", service.selectJob(42L, 100L).getSalaryText());
    }
}
