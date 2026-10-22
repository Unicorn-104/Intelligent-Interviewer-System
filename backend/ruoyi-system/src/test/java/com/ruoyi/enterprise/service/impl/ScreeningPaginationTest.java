package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.UUID;
import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.exceptions.PersistenceException;
import org.apache.ibatis.logging.nologging.NoLoggingImpl;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.github.pagehelper.Page;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInterceptor;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.system.mapper.DashboardMapper;

/** Reproduces the duplicate LIMIT with a real PageHelper interceptor and synthetic SQL data. */
class ScreeningPaginationTest
{
    SqlSession session;
    ScreeningServiceImpl service;
    ScreeningMapper mapper;
    DashboardMapper dashboard;

    @BeforeEach void setup() throws Exception
    {
        PageHelper.clearPage();
        var source = new UnpooledDataSource("org.h2.Driver", "jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=MySQL;DB_CLOSE_DELAY=-1", "sa", "");
        try (var connection = source.getConnection(); var statement = connection.createStatement())
        {
            statement.execute("create table t_cmp_binding (bnd_user_id bigint, bnd_company_id bigint, bnd_status int)");
            statement.execute("insert into t_cmp_binding values (3,1,1)");
        }
        var configuration = new Configuration(new Environment("pagination-regression", new JdbcTransactionFactory(), source));
        configuration.setLogImpl(NoLoggingImpl.class);
        var plugin = new PageInterceptor();
        var properties = new Properties(); properties.setProperty("helperDialect", "mysql");
        plugin.setProperties(properties); configuration.addInterceptor(plugin);
        try (var xml = getClass().getResourceAsStream("/mapper/system/DashboardMapper.xml"))
        {
            new XMLMapperBuilder(xml, configuration, "mapper/system/DashboardMapper.xml", configuration.getSqlFragments()).parse();
        }
        session = new SqlSessionFactoryBuilder().build(configuration).openSession();
        dashboard = session.getMapper(DashboardMapper.class);
        service = new ScreeningServiceImpl(); mapper = mock(ScreeningMapper.class);
        ReflectionTestUtils.setField(service, "dashboardMapper", dashboard);
        ReflectionTestUtils.setField(service, "screeningMapper", mapper);
        when(mapper.selectPosition(1L, 7L)).thenReturn(Map.of("positionId", 7L));
        when(mapper.selectResultsByPosition(7L)).thenReturn(new java.util.ArrayList<>());
    }

    @AfterEach void cleanup()
    {
        PageHelper.clearPage();
        if (session != null) session.close();
        if (service != null) service.shutdown();
    }

    @Test void reproducesOriginalDuplicateLimitOnScalarCompanyLookup()
    {
        PageHelper.startPage(1, 10, false);
        PersistenceException error = assertThrows(PersistenceException.class, () -> dashboard.selectCompanyIdByUser(3L));
        assertTrue(error.getMessage().toLowerCase().matches("(?s).*limit 1\\s+limit.*"));
    }

    @Test void resultsIgnoreStalePaginationBeforeLookingUpCompany()
    {
        PageHelper.startPage(1, 10, false);
        assertEquals(List.of(), service.listResults(3L, 7L));
        assertNull(PageHelper.getLocalPage());
        verify(mapper).selectResultsByPosition(7L);
    }

    @Test void reportIgnoresStalePaginationAndReturnsOwnedReport()
    {
        when(mapper.selectOwnedCandidate(1L, 11L)).thenReturn(Map.of("talentId", 11L));
        when(mapper.selectLatestAnalysis(1L, 11L)).thenReturn(Map.of("report", "{\"source\":\"llm\",\"recommendation\":\"演示数据：合成推荐理由\"}"));
        PageHelper.startPage(1, 10, false);
        assertEquals("llm", service.getReport(3L, 11L).get("source"));
        assertNull(PageHelper.getLocalPage());
    }

    @Test void taskListPaginatesOnlyIntendedQueryAndKeepsTotal()
    {
        Page<Map<String, Object>> result = new Page<>(2, 10); result.setTotal(23);
        when(mapper.selectTaskList(1L)).thenAnswer(call -> {
            assertNotNull(PageHelper.getLocalPage());
            assertEquals(2, PageHelper.getLocalPage().getPageNum());
            assertEquals(10, PageHelper.getLocalPage().getPageSize());
            return result;
        });
        PageHelper.startPage(1, 10, false);
        assertSame(result, service.listTasks(3L, 2, 10));
        assertEquals(23, result.getTotal());
        assertNull(PageHelper.getLocalPage());
    }

    @Test void failedTaskQueryStillCleansPaginationForNextOperation()
    {
        when(mapper.selectTaskList(1L)).thenThrow(new IllegalStateException("synthetic failure"));
        assertThrows(IllegalStateException.class, () -> service.listTasks(3L, 1, 10));
        assertNull(PageHelper.getLocalPage());
        assertEquals(1L, dashboard.selectCompanyIdByUser(3L));
    }
}
