package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseSettingsMapper;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;

/** 企业信息查看与编辑（求职者企业主页同源字段）的真实 Mapper 回归测试。 */
public class EnterpriseCompanyInfoTest
{
    private JdbcTemplate jdbc;
    private EnterpriseSettingsServiceImpl service;

    @BeforeEach
    void setUp() throws Exception
    {
        JdbcDataSource source = new JdbcDataSource();
        source.setURL("jdbc:h2:mem:company_info_" + UUID.randomUUID() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(source);
        jdbc.execute("""
            create table t_cmp (cmp_id bigint primary key, cmp_name varchar(100), cmp_industry varchar(50),
                cmp_size varchar(20), cmp_city varchar(50), cmp_address varchar(200),
                cmp_website varchar(255), cmp_intro varchar(4000), cmp_logo_url varchar(255),
                cmp_verify_status int, cmp_status int, cmp_updated_at timestamp)
            """);
        jdbc.execute("insert into t_cmp (cmp_id, cmp_name, cmp_industry, cmp_size, cmp_city, cmp_address, " +
                "cmp_website, cmp_intro, cmp_logo_url, cmp_verify_status, cmp_status) " +
                "values (2, '测试企业', '互联网', '100-499人', '杭州', '西湖区', " +
                "'https://example.com', '专注招聘的企业', null, 1, 1)");
        jdbc.execute("insert into t_cmp (cmp_id, cmp_name, cmp_verify_status, cmp_status) values (3, '同名企业占位', 0, 1)");
        SqlSessionFactoryBean factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setMapperLocations(new ClassPathResource("mapper/system/EnterpriseSettingsMapper.xml"));
        SqlSessionTemplate session = new SqlSessionTemplate(Objects.requireNonNull(factory.getObject()));
        EnterpriseSettingsServiceImpl target = new EnterpriseSettingsServiceImpl();
        ReflectionTestUtils.setField(target, "settingsMapper", session.getMapper(EnterpriseSettingsMapper.class));
        DashboardMapper dashboard = mock(DashboardMapper.class);
        when(dashboard.selectCompanyIdByUser(100L)).thenReturn(2L);
        when(dashboard.selectCompanyIdByUser(101L)).thenReturn(null);
        ReflectionTestUtils.setField(target, "dashboardMapper", dashboard);
        ProxyFactory proxy = new ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(source),
                new AnnotationTransactionAttributeSource()));
        service = (EnterpriseSettingsServiceImpl) proxy.getProxy();
    }

    @Test
    void readsOwnCompanyInfo()
    {
        Map<String, Object> info = service.companyInfo(2L);
        assertEquals("测试企业", info.get("name"));
        assertEquals("互联网", info.get("industry"));
        assertEquals("100-499人", info.get("size"));
        assertEquals("杭州", info.get("city"));
        assertEquals(1, ((Number) info.get("verifyStatus")).intValue());
    }

    @Test
    void updatesEditableFieldsAndReturnsFreshInfo()
    {
        Map<String, Object> form = new LinkedHashMap<>();
        form.put("name", " 测试企业科技 ");
        form.put("industry", "人工智能");
        form.put("size", "500-999人");
        form.put("city", "上海");
        form.put("address", "浦东新区");
        form.put("website", "https://example.com/new");
        form.put("intro", "新一代智能招聘平台");
        form.put("logoUrl", "https://example.com/logo.png");
        Map<String, Object> updated = service.updateCompanyInfo(2L, form);
        assertEquals("测试企业科技", updated.get("name"));
        assertEquals("人工智能", updated.get("industry"));
        assertEquals("上海", updated.get("city"));
        assertEquals("浦东新区", jdbc.queryForObject("select cmp_address from t_cmp where cmp_id = 2", String.class));
        assertEquals(1, ((Number) updated.get("verifyStatus")).intValue());
    }

    @Test
    void blankNameIsRejected()
    {
        Map<String, Object> form = new LinkedHashMap<>();
        form.put("name", "   ");
        ServiceException error = assertThrows(ServiceException.class, () -> service.updateCompanyInfo(2L, form));
        assertEquals("企业名称不能为空", error.getMessage());
        assertEquals("测试企业", jdbc.queryForObject("select cmp_name from t_cmp where cmp_id = 2", String.class));
    }

    @Test
    void overlongFieldIsRejectedBeforeWriting()
    {
        Map<String, Object> form = new LinkedHashMap<>();
        form.put("name", "x".repeat(101));
        assertThrows(ServiceException.class, () -> service.updateCompanyInfo(2L, form));
        Map<String, Object> industry = new LinkedHashMap<>();
        industry.put("name", "测试企业");
        industry.put("industry", "y".repeat(51));
        assertThrows(ServiceException.class, () -> service.updateCompanyInfo(2L, industry));
        assertEquals("互联网", jdbc.queryForObject("select cmp_industry from t_cmp where cmp_id = 2", String.class));
    }

    @Test
    void missingCompanyIsRejected()
    {
        assertThrows(ServiceException.class, () -> service.companyInfo(999L));
        Map<String, Object> form = new LinkedHashMap<>();
        form.put("name", "不存在企业");
        assertThrows(ServiceException.class, () -> service.updateCompanyInfo(999L, form));
    }

    @Test
    void requireCompanyIdRejectsUnboundUsersWithoutFallingBack()
    {
        assertEquals(2L, service.requireCompanyId(100L));
        ServiceException error = assertThrows(ServiceException.class, () -> service.requireCompanyId(101L));
        assertEquals(403, error.getCode());
    }
}
