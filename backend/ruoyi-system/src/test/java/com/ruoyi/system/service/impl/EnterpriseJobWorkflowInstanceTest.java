package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
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
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;

/**
 * 招聘流程保存与投递流程实例的真实 Mapper 回归测试（H2 + 现有 XML）。
 *
 * <p>覆盖两个缺陷：
 * 1. insertTemplate 多参数 + useGeneratedKeys 导致保存流程报 MyBatisSystemException；
 * 2. 新投递不创建 t_process_instance，企业端岗位详情/漏斗/筛选看不到新求职者。</p>
 */
public class EnterpriseJobWorkflowInstanceTest
{
    private JdbcTemplate jdbc;
    private EnterpriseJobServiceImpl service;

    /** H2 DATE_FORMAT 别名实现，仅支持本测试涉及的 '%Y-%m-%d' 等简单模式。 */
    public static String dateFormat(java.sql.Timestamp value, String pattern)
    {
        if (value == null)
        {
            return null;
        }
        String javaPattern = pattern
                .replace("%Y", "yyyy")
                .replace("%m", "MM")
                .replace("%d", "dd")
                .replace("%H", "HH")
                .replace("%i", "mm")
                .replace("%s", "ss");
        return new java.text.SimpleDateFormat(javaPattern).format(new java.util.Date(value.getTime()));
    }

    @BeforeEach
    void setUp() throws Exception
    {
        JdbcDataSource source = new JdbcDataSource();
        source.setURL("jdbc:h2:mem:job_workflow_" + UUID.randomUUID() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(source);
        jdbc.execute("create table t_cmp (cmp_id bigint primary key, cmp_name varchar(100), cmp_city varchar(50), cmp_status int)");
        jdbc.execute("create table t_cmp_binding (bnd_user_id bigint, bnd_company_id bigint, bnd_status int)");
        jdbc.execute("""
            create table t_pos (pos_id bigint auto_increment primary key, pos_company_id bigint,
                pos_publisher_id bigint, pos_title varchar(100), pos_department varchar(50),
                pos_work_city varchar(50), pos_salary_min decimal(10,2), pos_salary_max decimal(10,2),
                pos_experience_required varchar(20), pos_education_required tinyint, pos_job_type tinyint,
                pos_jd_json varchar(20000), pos_status tinyint, pos_created_at timestamp,
                pos_updated_at timestamp, pos_process_template_id bigint)
            """);
        jdbc.execute("""
            create table t_process_template (ptl_id bigint auto_increment primary key,
                ptl_company_id bigint, ptl_name varchar(100), ptl_position_id bigint,
                ptl_version varchar(20), ptl_status int)
            """);
        jdbc.execute("""
            create table t_process_stage (psg_id bigint auto_increment primary key,
                psg_template_id bigint, psg_name varchar(100), psg_type int, psg_sort_order int,
                psg_is_required int, psg_pass_threshold int, psg_interviewer_config_json varchar(2000))
            """);
        jdbc.execute("""
            create table t_process_instance (pin_id bigint auto_increment primary key,
                pin_candidate_id bigint, pin_position_id bigint, pin_template_id bigint,
                pin_current_stage_id bigint, pin_status int, pin_start_at timestamp)
            """);
        jdbc.execute("""
            create table t_tal (tal_id bigint auto_increment primary key, tal_user_id bigint,
                tal_company_id bigint, tal_resume_id bigint, tal_status int, tal_process_instance_id bigint)
            """);
        jdbc.execute("""
            create table t_app_record (app_id bigint auto_increment primary key, app_candidate_id bigint,
                app_position_id bigint, app_resume_id bigint, app_status int,
                app_process_instance_id bigint, app_created_at timestamp)
            """);
        // H2 无 MySQL DATE_FORMAT；为复用 selectJobById 注册同名别名
        jdbc.execute("CREATE ALIAS IF NOT EXISTS DATE_FORMAT FOR \"" +
                EnterpriseJobWorkflowInstanceTest.class.getName() + ".dateFormat\"");
        SqlSessionFactoryBean factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setMapperLocations(new ClassPathResource("mapper/system/EnterpriseJobMapper.xml"));
        SqlSessionTemplate session = new SqlSessionTemplate(Objects.requireNonNull(factory.getObject()));
        EnterpriseJobServiceImpl target = new EnterpriseJobServiceImpl();
        ReflectionTestUtils.setField(target, "jobMapper", session.getMapper(EnterpriseJobMapper.class));
        DashboardMapper dashboard = mock(DashboardMapper.class);
        when(dashboard.selectCompanyIdByUser(100L)).thenReturn(2L);
        ReflectionTestUtils.setField(target, "dashboardMapper", dashboard);
        ProxyFactory proxy = new ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(source),
                new AnnotationTransactionAttributeSource()));
        service = (EnterpriseJobServiceImpl) proxy.getProxy();
    }

    private void company(int companyId)
    {
        jdbc.update("insert into t_cmp values (?, 'Test company', 'Test city', 1)", companyId);
        jdbc.update("insert into t_cmp_binding values (100, ?, 1)", companyId);
    }

    private long position(int companyId)
    {
        jdbc.update("""
            insert into t_pos (pos_company_id, pos_publisher_id, pos_title, pos_department, pos_work_city,
                pos_status, pos_jd_json, pos_created_at, pos_updated_at, pos_process_template_id)
            values (?, 100, 'Agent 开发工程师', 'Engineering', 'Test city', 1, '{}', now(), now(), null)
            """, companyId);
        return jdbc.queryForObject("select max(pos_id) from t_pos", Long.class);
    }

    private List<Map<String, Object>> stages()
    {
        List<Map<String, Object>> stages = new ArrayList<>();
        Map<String, Object> first = new LinkedHashMap<>();
        first.put("name", "AI 简历筛选");
        first.put("type", 2);
        first.put("required", true);
        first.put("threshold", 70);
        first.put("duration", 45);
        first.put("target", "");
        first.put("skip", false);
        first.put("terminate", false);
        stages.add(first);
        Map<String, Object> second = new LinkedHashMap<>();
        second.put("name", "技术面试");
        second.put("type", 3);
        second.put("required", false);
        second.put("threshold", 80);
        second.put("duration", 60);
        stages.add(second);
        return stages;
    }

    @Test
    void saveWorkflowWithoutTemplateCreatesTemplateAndStages()
    {
        company(2);
        long positionId = position(2);
        Map<String, Object> result = service.saveWorkflow(100L, positionId, "岗位招聘流程", stages());
        assertNotNull(result.get("templateId"));
        assertEquals(1, jdbc.queryForObject("select count(*) from t_process_template where ptl_position_id = ?",
                Integer.class, positionId));
        assertEquals(2, jdbc.queryForObject(
                "select count(*) from t_process_stage s join t_process_template t on t.ptl_id = s.psg_template_id " +
                "where t.ptl_position_id = ?", Integer.class, positionId));
        Long bound = jdbc.queryForObject("select pos_process_template_id from t_pos where pos_id = ?",
                Long.class, positionId);
        assertNotNull(bound);
        assertEquals(result.get("templateId"), bound);
    }

    @Test
    void saveWorkflowWithExistingTemplateBumpsVersionAndRebuildsStages()
    {
        company(2);
        long positionId = position(2);
        service.saveWorkflow(100L, positionId, "岗位招聘流程", stages());
        Map<String, Object> result = service.saveWorkflow(100L, positionId, "岗位招聘流程", stages().subList(0, 1));
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from t_process_stage s join t_process_template t on t.ptl_id = s.psg_template_id " +
                "where t.ptl_position_id = ?", Integer.class, positionId));
        // H2 对 decimal->char 的格式化与 MySQL 不同，仅断言版本已递增
        String version = jdbc.queryForObject(
                "select t.ptl_version from t_process_template t where t.ptl_position_id = ?", String.class, positionId);
        assertNotEquals("v1.0", version);
        assertEquals(result.get("templateId"), jdbc.queryForObject(
                "select pos_process_template_id from t_pos where pos_id = ?", Long.class, positionId));
    }

    @Test
    void ensureProcessInstanceCreatesTemplateInstanceAndBacklinks()
    {
        company(2);
        long positionId = position(2);
        jdbc.update("insert into t_tal (tal_user_id, tal_company_id, tal_status) values (104, 2, 0)");
        long talentId = jdbc.queryForObject("select max(tal_id) from t_tal", Long.class);
        jdbc.update("insert into t_app_record (app_candidate_id, app_position_id, app_resume_id, app_status, app_created_at) " +
                "values (?, ?, 1, 0, now())", talentId, positionId);

        Long pinId = service.ensureProcessInstance(2L, talentId, positionId);
        assertNotNull(pinId);
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from t_process_instance where pin_position_id = ? and pin_candidate_id = ?",
                Integer.class, positionId, talentId));
        // 岗位无模板时自动创建并绑定空模板，保证实例外键成立
        assertNotNull(jdbc.queryForObject("select pos_process_template_id from t_pos where pos_id = ?",
                Long.class, positionId));
        assertEquals(pinId, jdbc.queryForObject(
                "select app_process_instance_id from t_app_record where app_candidate_id = ? and app_position_id = ?",
                Long.class, talentId, positionId));
        assertEquals(pinId, jdbc.queryForObject(
                "select tal_process_instance_id from t_tal where tal_id = ?", Long.class, talentId));
    }

    @Test
    void ensureProcessInstanceStartsAtFirstConfiguredStage()
    {
        company(2);
        long positionId = position(2);
        service.saveWorkflow(100L, positionId, "岗位招聘流程", stages());
        jdbc.update("insert into t_tal (tal_user_id, tal_company_id, tal_status) values (104, 2, 0)");
        long talentId = jdbc.queryForObject("select max(tal_id) from t_tal", Long.class);
        jdbc.update("insert into t_app_record (app_candidate_id, app_position_id, app_resume_id, app_status, app_created_at) " +
                "values (?, ?, 1, 0, now())", talentId, positionId);

        Long pinId = service.ensureProcessInstance(2L, talentId, positionId);
        Long stageId = jdbc.queryForObject("select pin_current_stage_id from t_process_instance where pin_id = ?",
                Long.class, pinId);
        assertEquals(jdbc.queryForObject(
                "select min(psg_id) from t_process_stage where psg_template_id = " +
                "(select pos_process_template_id from t_pos where pos_id = ?)", Long.class, positionId), stageId);
    }

    @Test
    void ensureProcessInstanceIsIdempotentPerCandidateAndPosition()
    {
        company(2);
        long positionId = position(2);
        jdbc.update("insert into t_tal (tal_user_id, tal_company_id, tal_status) values (104, 2, 0)");
        long talentId = jdbc.queryForObject("select max(tal_id) from t_tal", Long.class);
        jdbc.update("insert into t_app_record (app_candidate_id, app_position_id, app_resume_id, app_status, app_created_at) " +
                "values (?, ?, 1, 0, now())", talentId, positionId);

        Long first = service.ensureProcessInstance(2L, talentId, positionId);
        Long second = service.ensureProcessInstance(2L, talentId, positionId);
        assertEquals(first, second);
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from t_process_instance where pin_position_id = ? and pin_candidate_id = ?",
                Integer.class, positionId, talentId));
        assertEquals(1, jdbc.queryForObject(
                "select count(*) from t_process_template where ptl_position_id = ?", Integer.class, positionId));
    }
}
