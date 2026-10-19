package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import com.ruoyi.enterprise.mapper.EnterpriseJdMapper;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;

class EnterpriseJobSkillsTransactionTest
{
    private JdbcTemplate jdbc;
    private EnterpriseJobServiceImpl service;

    @BeforeEach
    void setUp() throws Exception
    {
        JdbcDataSource source = new JdbcDataSource();
        source.setURL("jdbc:h2:mem:job_skills_" + UUID.randomUUID() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(source);
        jdbc.execute("create table t_cmp (cmp_id bigint primary key, cmp_name varchar(100), cmp_city varchar(50), cmp_status int)");
        jdbc.execute("insert into t_cmp values (2, 'Test company', 'Test city', 1)");
        jdbc.execute("create table t_cmp_binding (bnd_user_id bigint, bnd_company_id bigint, bnd_status int)");
        jdbc.execute("insert into t_cmp_binding values (100, 2, 1)");
        jdbc.execute("""
            create table t_pos (pos_id bigint auto_increment primary key, pos_company_id bigint,
                pos_publisher_id bigint, pos_title varchar(100), pos_department varchar(50),
                pos_work_city varchar(50), pos_salary_min decimal(10,2), pos_salary_max decimal(10,2),
                pos_experience_required varchar(20), pos_education_required tinyint, pos_job_type tinyint,
                pos_jd_json varchar(20000), pos_status tinyint)
            """);
        jdbc.execute("""
            create table t_pos_skill (psk_id bigint auto_increment primary key,
                psk_position_id bigint not null references t_pos(pos_id),
                psk_name varchar(50) not null check (psk_name <> 'FAIL_SKILL'), psk_required tinyint)
            """);
        SqlSessionFactoryBean factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setMapperLocations(new ClassPathResource("mapper/system/EnterpriseJobMapper.xml"),
                new ClassPathResource("mapper/system/DashboardMapper.xml"),
                new ClassPathResource("mapper/enterprise/EnterpriseJdMapper.xml"));
        SqlSessionTemplate session = new SqlSessionTemplate(Objects.requireNonNull(factory.getObject()));
        EnterpriseJobServiceImpl target = new EnterpriseJobServiceImpl();
        ReflectionTestUtils.setField(target, "jobMapper", session.getMapper(EnterpriseJobMapper.class));
        ReflectionTestUtils.setField(target, "dashboardMapper", session.getMapper(DashboardMapper.class));
        ReflectionTestUtils.setField(target, "jdMapper", session.getMapper(EnterpriseJdMapper.class));
        ProxyFactory proxy = new ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(source),
                new AnnotationTransactionAttributeSource()));
        service = (EnterpriseJobServiceImpl) proxy.getProxy();
    }

    private Map<String, Object> form()
    {
        Map<String, Object> form = new LinkedHashMap<>();
        form.put("title", "Skills transaction test"); form.put("dept", "Engineering"); form.put("city", "Test city");
        form.put("responsibilities", List.of("Build applications")); form.put("requirements", List.of("Java"));
        return form;
    }

    @Test
    void commitsJobAndSkillsUsingExistingMapperSql()
    {
        Map<String, Object> form = form();
        form.put("skills", List.of(Map.of("name", "Java", "required", 1), Map.of("name", "Spring", "required", 0)));
        Long positionId = ((Number) service.createJob(100L, form).get("posId")).longValue();
        assertEquals(1, jdbc.queryForObject("select count(*) from t_pos where pos_id = ?", Integer.class, positionId));
        assertEquals(2, jdbc.queryForObject("select count(*) from t_pos_skill where psk_position_id = ?", Integer.class, positionId));
        assertEquals(List.of("Java", "Spring"), jdbc.queryForList("select psk_name from t_pos_skill order by psk_id", String.class));
        assertEquals(List.of(1, 0), jdbc.queryForList("select psk_required from t_pos_skill order by psk_id", Integer.class));
    }

    @Test
    void failedSecondSkillRollsBackJobAndAlreadyInsertedSkill()
    {
        Map<String, Object> form = form();
        form.put("skills", List.of("Java", "FAIL_SKILL"));
        DataIntegrityViolationException failure = assertThrows(DataIntegrityViolationException.class, () -> service.createJob(100L, form));
        assertInstanceOf(java.sql.SQLException.class, failure.getMostSpecificCause());
        assertEquals("23513", ((java.sql.SQLException) failure.getMostSpecificCause()).getSQLState());
        assertEquals(0, jdbc.queryForObject("select count(*) from t_pos", Integer.class));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_pos_skill", Integer.class));
    }

    @Test
    void omittedAndEmptySkillsKeepExistingPublishingBehavior()
    {
        service.createJob(100L, form());
        Map<String, Object> empty = form(); empty.put("skills", List.of());
        service.createJob(100L, empty);
        assertEquals(2, jdbc.queryForObject("select count(*) from t_pos", Integer.class));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_pos_skill", Integer.class));
    }
}
