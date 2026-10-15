package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class EnterpriseJobPublishingTest
{
    @Mock private EnterpriseJobMapper jobMapper;
    @Mock private DashboardMapper dashboardMapper;
    @InjectMocks private EnterpriseJobServiceImpl service;

    @BeforeEach
    void company()
    {
        lenient().when(dashboardMapper.selectCompanyIdByUser(100L)).thenReturn(2L);
        lenient().when(jobMapper.selectPublishingCompany(2L))
                .thenReturn(Map.of("id", 2L, "name", "Test company", "city", "Test city"));
    }

    private Map<String, Object> form()
    {
        Map<String, Object> form = new LinkedHashMap<>();
        form.put("title", "  Mobile Engineer  ");
        form.put("dept", "Engineering");
        form.put("city", "Test city");
        form.put("salaryMin", "15000.50");
        form.put("salaryMax", "25000");
        form.put("education", 3);
        form.put("jobType", 1);
        form.put("responsibilities", List.of("Build apps\twith accessibility", "Review \"code\""));
        form.put("requirements", List.of("Flutter experience"));
        return form;
    }

    @Test
    @SuppressWarnings("unchecked")
    void publishesBoundCompanyWithGeneratedIdAndEscapedJd()
    {
        when(jobMapper.insertJob(anyMap())).thenAnswer(call -> {
            Map<String, Object> job = call.getArgument(0);
            job.put("posId", 42L);
            return 1;
        });
        Map<String, Object> form = form();
        form.put("companyId", 999L);
        form.put("publisherId", 999L);
        Map<String, Object> result = service.createJob(100L, form);
        assertEquals(42L, result.get("posId"));
        assertEquals(1, result.get("status"));
        ArgumentCaptor<Map<String, Object>> capture = ArgumentCaptor.forClass(Map.class);
        verify(jobMapper).insertJob(capture.capture());
        Map<String, Object> saved = capture.getValue();
        assertEquals(2L, saved.get("companyId"));
        assertEquals(100L, saved.get("publisherId"));
        assertEquals("Mobile Engineer", saved.get("title"));
        assertEquals(new BigDecimal("15000.50"), saved.get("salaryMin"));
        assertEquals(form.get("responsibilities"), JSON.parseObject((String) saved.get("jdJson"))
                .getJSONArray("responsibilities").toJavaList(String.class));
    }

    @Test
    void negotiableSalaryAndUnrestrictedEducationRemainNull()
    {
        when(jobMapper.insertJob(anyMap())).thenAnswer(call -> {
            Map<String, Object> job = call.getArgument(0);
            assertNull(job.get("salaryMin"));
            assertNull(job.get("salaryMax"));
            assertNull(job.get("education"));
            job.put("posId", 43L);
            return 1;
        });
        Map<String, Object> form = form();
        form.remove("salaryMin"); form.remove("salaryMax"); form.remove("education");
        service.createJob(100L, form);
    }

    @Test
    void rejectsInvalidSalaryAndEnumsBeforeWriting()
    {
        for (Object value : List.of("not-money", "-1", "0", "1.234", "100000000"))
        {
            Map<String, Object> form = form(); form.put("salaryMin", value);
            assertEquals(400, assertThrows(ServiceException.class, () -> service.createJob(100L, form)).getCode());
        }
        Map<String, Object> reversed = form(); reversed.put("salaryMin", "30000");
        assertThrows(ServiceException.class, () -> service.createJob(100L, reversed));
        Map<String, Object> partial = form(); partial.remove("salaryMax");
        assertThrows(ServiceException.class, () -> service.createJob(100L, partial));
        for (String key : List.of("education", "jobType", "status"))
        {
            Map<String, Object> form = form(); form.put(key, "2.5");
            assertEquals(400, assertThrows(ServiceException.class, () -> service.createJob(100L, form)).getCode());
        }
        verify(jobMapper, never()).insertJob(anyMap());
    }

    @Test
    void rejectsMissingOverlongAndInvalidDescriptions()
    {
        for (String key : List.of("title", "dept", "city", "requirements", "responsibilities"))
        {
            Map<String, Object> form = form(); form.put(key, "  ");
            assertEquals(400, assertThrows(ServiceException.class, () -> service.createJob(100L, form)).getCode());
        }
        Map<String, Object> longTitle = form(); longTitle.put("title", "x".repeat(101));
        assertThrows(ServiceException.class, () -> service.createJob(100L, longTitle));
        Map<String, Object> malformed = form(); malformed.put("requirements", List.of(123));
        assertThrows(ServiceException.class, () -> service.createJob(100L, malformed));
        verify(jobMapper, never()).insertJob(anyMap());
    }

    @Test
    void unboundUserCannotPublishIntoFallbackCompany()
    {
        when(dashboardMapper.selectCompanyIdByUser(200L)).thenReturn(null);
        assertEquals(403, assertThrows(ServiceException.class, () -> service.createJob(200L, form())).getCode());
        assertEquals(403, assertThrows(ServiceException.class, () -> service.publishingOptions(200L)).getCode());
        verify(jobMapper, never()).insertJob(anyMap());
    }

    @Test
    void inactiveCompanyCannotPublish()
    {
        when(jobMapper.selectPublishingCompany(2L)).thenReturn(null);
        assertEquals(403, assertThrows(ServiceException.class, () -> service.createJob(100L, form())).getCode());
        verify(jobMapper, never()).insertJob(anyMap());
    }
}
