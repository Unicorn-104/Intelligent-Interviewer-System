package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.github.pagehelper.PageHelper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import com.ruoyi.enterprise.mapper.TalentPoolMapper;
import com.ruoyi.system.mapper.DashboardMapper;

class TalentSearchServiceTest
{
    TalentPoolServiceImpl service;
    TalentPoolMapper mapper;
    DashboardMapper dashboard;
    @BeforeEach void setup()
    {
        service = new TalentPoolServiceImpl(); mapper = mock(TalentPoolMapper.class); dashboard = mock(DashboardMapper.class);
        ReflectionTestUtils.setField(service, "talentPoolMapper", mapper);
        ReflectionTestUtils.setField(service, "dashboardMapper", dashboard);
        when(dashboard.selectCompanyIdByUser(9L)).thenReturn(2L);
    }
    @AfterEach void clear() { PageHelper.clearPage(); }

    @Test void advancedFiltersAreValidatedScopedAndPagedOnce()
    {
        var criteria = new TalentSearchCriteria(); criteria.setMinimumEducation(3); criteria.setExperienceRange("3to5");
        criteria.setCity(" 合成城市 "); criteria.setCityType("target"); criteria.setLoginWithinDays(7);
        when(mapper.selectFilteredTalentList(eq(2L), eq("姓名"), eq("Java"), eq("后端"), eq(3), eq(2), same(criteria)))
            .thenAnswer(call -> { assertEquals(4, PageHelper.getLocalPage().getPageNum());
                assertEquals(20, PageHelper.getLocalPage().getPageSize()); return List.of(Map.of("talentId", 11)); });
        PageHelper.startPage(99, 1);
        var rows = service.listTalents(9L, "姓名", "Java", "后端", 3, 2, 4, 20, criteria);
        assertEquals(1, rows.size()); assertEquals("合成城市", criteria.getCity());
        assertEquals(36, criteria.getMinimumWorkMonths()); assertEquals(60, criteria.getMaximumWorkMonths());
        assertEquals(criteria.getReferenceTime().minusDays(7), criteria.getLoginSince());
        assertNull(PageHelper.getLocalPage());
    }
    @Test void oldEntryPointRetainsCompatibilityAndNoExtraRestrictions()
    {
        service.listTalents(9L, null, null, null, null, null, 1, 20);
        verify(mapper).selectFilteredTalentList(eq(2L), isNull(), isNull(), isNull(), isNull(), isNull(),
            argThat(c -> c.getMinimumEducation() == null && c.getExperienceRange() == null && c.getCity() == null && c.getLoginWithinDays() == null));
        assertNull(PageHelper.getLocalPage());
    }
    @Test void invalidCriteriaNeverReachMapper()
    {
        var bad = new TalentSearchCriteria(); bad.setMinimumEducation(9);
        assertThrows(ServiceException.class, () -> service.listTalents(9L,null,null,null,null,null,1,20,bad));
        bad.setMinimumEducation(null); bad.setExperienceRange("invented");
        assertThrows(ServiceException.class, () -> service.listTalents(9L,null,null,null,null,null,1,20,bad));
        bad.setExperienceRange(null); bad.setCityType("sql-column");
        assertThrows(ServiceException.class, () -> service.listTalents(9L,null,null,null,null,null,1,20,bad));
        bad.setCityType("target"); bad.setCity("a".repeat(51));
        assertThrows(ServiceException.class, () -> service.listTalents(9L,null,null,null,null,null,1,20,bad));
        bad.setCity(null); bad.setLoginWithinDays(999);
        assertThrows(ServiceException.class, () -> service.listTalents(9L,null,null,null,null,null,1,20,bad));
        assertThrows(ServiceException.class, () -> service.listTalents(9L,null,null,null,null,null,0,20,new TalentSearchCriteria()));
        assertThrows(ServiceException.class, () -> service.listTalents(9L,null,null,null,null,null,2,101,new TalentSearchCriteria()));
        verifyNoInteractions(mapper);
    }
    @Test void missingCompanyCannotFallBackToAnotherCompany()
    {
        when(dashboard.selectCompanyIdByUser(9L)).thenReturn(null);
        assertThrows(ServiceException.class, () -> service.listTalents(9L,null,null,null,null,null,1,20));
        assertThrows(ServiceException.class, () -> service.getTalentOptions(9L));
        verifyNoInteractions(mapper);
    }
    @Test void optionCitiesAreCompanyScopedAndReadWithoutStalePagination()
    {
        PageHelper.startPage(99,1);
        when(mapper.selectTalentCities(2L,"current")).thenAnswer(call -> {assertNull(PageHelper.getLocalPage());return List.of("所在城市");});
        when(mapper.selectTalentCities(2L,"target")).thenReturn(List.of("期望城市"));
        when(mapper.selectTalentDirections(2L)).thenReturn(List.of()); when(mapper.selectTalentTagNames(2L)).thenReturn(List.of());
        var options = service.getTalentOptions(9L);
        assertEquals(2,options.get("searchFilterVersion"));
        assertEquals(List.of("所在城市"),options.get("currentCities")); assertEquals(List.of("期望城市"),options.get("targetCities"));
    }
    @Test void mapperFailureStillClearsPagination()
    {
        when(mapper.selectFilteredTalentList(anyLong(),any(),any(),any(),any(),any(),any())).thenThrow(new IllegalStateException("synthetic"));
        assertThrows(IllegalStateException.class, () -> service.listTalents(9L,null,null,null,null,null,1,20));
        assertNull(PageHelper.getLocalPage());
    }
}
