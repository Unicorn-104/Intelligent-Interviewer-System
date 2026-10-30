package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.Objects;
import java.util.UUID;
import com.ruoyi.common.exception.ServiceException;
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
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;

/** 删除岗位：任何状态可删；无外键的业务数据由服务显式清理，有外键的数据由数据库级联删除。 */
public class EnterpriseJobDeleteTest
{
    private JdbcTemplate jdbc;
    private EnterpriseJobServiceImpl service;

    public static String dateFormat(java.sql.Timestamp value, String pattern)
    {
        if (value == null)
        {
            return null;
        }
        String javaPattern = pattern
                .replace("%Y", "yyyy").replace("%m", "MM").replace("%d", "dd")
                .replace("%H", "HH").replace("%i", "mm").replace("%s", "ss");
        return new java.text.SimpleDateFormat(javaPattern).format(new java.util.Date(value.getTime()));
    }

    @BeforeEach
    void setUp() throws Exception
    {
        JdbcDataSource source = new JdbcDataSource();
        source.setURL("jdbc:h2:mem:job_delete_" + UUID.randomUUID() + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1");
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
        jdbc.execute("create table t_pos_skill (psk_id bigint auto_increment primary key, psk_position_id bigint, psk_name varchar(50), psk_required tinyint)");
        jdbc.execute("create table t_process_template (ptl_id bigint auto_increment primary key, ptl_name varchar(100), ptl_version varchar(20))");
        jdbc.execute("create table t_app_record (app_id bigint auto_increment primary key, app_position_id bigint)");
        jdbc.execute("create table t_process_instance (pin_id bigint auto_increment primary key, pin_position_id bigint)");
        jdbc.execute("create table t_sch_appointment (apt_id bigint auto_increment primary key, apt_position_id bigint)");
        jdbc.execute("create table t_sch_slot (slt_id bigint auto_increment primary key, slt_position_id bigint, slt_status int)");
        jdbc.execute("create table t_ai_candidate_analysis (asr_position_id bigint)");
        jdbc.execute("create table t_ai_screening_result (asr_position_id bigint)");
        jdbc.execute("create table t_ai_screening_task (ast_position_id bigint)");
        jdbc.execute("create table t_sch_reschedule_request (rsr_id bigint auto_increment primary key, rsr_appointment_id bigint, rsr_pending_appointment_id bigint)");
        jdbc.execute("create table t_exam_schedule (esd_id bigint auto_increment primary key, esd_position_id bigint)");
        jdbc.execute("create table t_exam_record (erc_id bigint auto_increment primary key, erc_schedule_id bigint)");
        jdbc.execute("create table t_int_session (ses_id bigint auto_increment primary key, ses_position_id bigint)");
        jdbc.execute("create table t_int_meeting_state (mst_id bigint auto_increment primary key, mst_session_id bigint)");
        jdbc.execute("create table t_int_participant_state (pst_id bigint auto_increment primary key, pst_session_id bigint)");
        jdbc.execute("create table t_int_copilot (cpt_id bigint auto_increment primary key, cpt_session_id bigint)");
        jdbc.execute("create table t_tal (tal_id bigint auto_increment primary key, tal_process_instance_id bigint, tal_exam_record_id bigint)");
        jdbc.execute("CREATE ALIAS IF NOT EXISTS DATE_FORMAT FOR \"" +
                EnterpriseJobDeleteTest.class.getName() + ".dateFormat\"");
        SqlSessionFactoryBean factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setMapperLocations(new ClassPathResource("mapper/system/EnterpriseJobMapper.xml"),
                new ClassPathResource("mapper/enterprise/EnterpriseJdMapper.xml"));
        SqlSessionTemplate session = new SqlSessionTemplate(Objects.requireNonNull(factory.getObject()));
        EnterpriseJobServiceImpl target = new EnterpriseJobServiceImpl();
        ReflectionTestUtils.setField(target, "jobMapper", session.getMapper(EnterpriseJobMapper.class));
        ReflectionTestUtils.setField(target, "jdMapper", session.getMapper(EnterpriseJdMapper.class));
        DashboardMapper dashboard = mock(DashboardMapper.class);
        when(dashboard.selectCompanyIdByUser(100L)).thenReturn(2L);
        ReflectionTestUtils.setField(target, "dashboardMapper", dashboard);
        ProxyFactory proxy = new ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(source),
                new AnnotationTransactionAttributeSource()));
        service = (EnterpriseJobServiceImpl) proxy.getProxy();
        jdbc.update("insert into t_cmp values (2, 'Test company', 'Test city', 1)");
    }

    private long position(int status)
    {
        jdbc.update("""
            insert into t_pos (pos_company_id, pos_publisher_id, pos_title, pos_department, pos_work_city,
                pos_status, pos_jd_json, pos_created_at, pos_updated_at, pos_process_template_id)
            values (2, 100, 'Agent 开发工程师', 'Engineering', 'Test city', ?, '{}', now(), now(), null)
            """, status);
        return jdbc.queryForObject("select max(pos_id) from t_pos", Long.class);
    }

    /** 无业务数据时任何状态都可删，岗位与技能关联一并删除。 */
    @Test
    void deletesJobWithoutBusinessDataRegardlessOfStatus()
    {
        long draft = position(0);
        jdbc.update("insert into t_pos_skill (psk_position_id, psk_name, psk_required) values (?, 'Java', 1)", draft);
        assertEquals(draft, ((Number) service.deleteDraftJob(100L, draft).get("posId")).longValue());
        assertEquals(0, jdbc.queryForObject("select count(*) from t_pos where pos_id = ?", Integer.class, draft));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_pos_skill where psk_position_id = ?", Integer.class, draft));

        long published = position(1);
        service.deleteDraftJob(100L, published);
        assertEquals(0, jdbc.queryForObject("select count(*) from t_pos where pos_id = ?", Integer.class, published));
    }

    /** 已有投递、面试、笔试等业务数据时仍可删，无外键的业务数据被显式清理，人才档案仅解除关联。 */
    @Test
    void deletesJobWithBusinessDataAndCleansRelatedRecords()
    {
        long positionId = position(1);
        jdbc.update("insert into t_app_record (app_position_id) values (?)", positionId);
        jdbc.update("insert into t_process_instance (pin_position_id) values (?)", positionId);
        long instanceId = jdbc.queryForObject("select max(pin_id) from t_process_instance", Long.class);
        jdbc.update("insert into t_sch_appointment (apt_position_id) values (?)", positionId);
        long appointmentId = jdbc.queryForObject("select max(apt_id) from t_sch_appointment", Long.class);
        jdbc.update("insert into t_ai_candidate_analysis (asr_position_id) values (?)", positionId);
        jdbc.update("insert into t_ai_screening_result (asr_position_id) values (?)", positionId);
        jdbc.update("insert into t_ai_screening_task (ast_position_id) values (?)", positionId);
        jdbc.update("insert into t_sch_reschedule_request (rsr_appointment_id, rsr_pending_appointment_id) values (?, ?)", appointmentId, appointmentId);
        jdbc.update("insert into t_exam_schedule (esd_position_id) values (?)", positionId);
        long scheduleId = jdbc.queryForObject("select max(esd_id) from t_exam_schedule", Long.class);
        jdbc.update("insert into t_exam_record (erc_schedule_id) values (?)", scheduleId);
        long examRecordId = jdbc.queryForObject("select max(erc_id) from t_exam_record", Long.class);
        jdbc.update("insert into t_int_session (ses_position_id) values (?)", positionId);
        long sessionId = jdbc.queryForObject("select max(ses_id) from t_int_session", Long.class);
        jdbc.update("insert into t_int_meeting_state (mst_session_id) values (?)", sessionId);
        jdbc.update("insert into t_int_participant_state (pst_session_id) values (?)", sessionId);
        jdbc.update("insert into t_int_copilot (cpt_session_id) values (?)", sessionId);
        jdbc.update("insert into t_tal (tal_process_instance_id, tal_exam_record_id) values (?, ?)", instanceId, examRecordId);

        assertEquals(positionId, ((Number) service.deleteDraftJob(100L, positionId).get("posId")).longValue());

        assertEquals(0, jdbc.queryForObject("select count(*) from t_pos where pos_id = ?", Integer.class, positionId));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_ai_candidate_analysis where asr_position_id = ?", Integer.class, positionId));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_ai_screening_result where asr_position_id = ?", Integer.class, positionId));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_ai_screening_task where ast_position_id = ?", Integer.class, positionId));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_sch_reschedule_request where rsr_appointment_id = ?", Integer.class, appointmentId));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_int_meeting_state where mst_session_id = ?", Integer.class, sessionId));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_int_participant_state where pst_session_id = ?", Integer.class, sessionId));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_int_copilot where cpt_session_id = ?", Integer.class, sessionId));
        // 人才档案保留，但与本岗位流程实例/笔试记录的关联已解除
        assertEquals(1, jdbc.queryForObject("select count(*) from t_tal", Integer.class));
        assertNull(jdbc.queryForObject("select tal_process_instance_id from t_tal where tal_id = (select max(tal_id) from t_tal)", Long.class));
        assertNull(jdbc.queryForObject("select tal_exam_record_id from t_tal where tal_id = (select max(tal_id) from t_tal)", Long.class));
    }

    /** 岗位删除显式清理面试官时段：不残留孤儿占用时段，也不影响其他岗位的时段。 */
    @Test
    void deletesJobClearsItsSlotsAndKeepsOtherPositionSlots()
    {
        long positionId = position(1);
        long otherPositionId = position(1);
        jdbc.update("insert into t_sch_slot (slt_position_id, slt_status) values (?, 0)", positionId);
        jdbc.update("insert into t_sch_slot (slt_position_id, slt_status) values (?, 1)", positionId);
        jdbc.update("insert into t_sch_slot (slt_position_id, slt_status) values (?, 0)", otherPositionId);

        assertEquals(positionId, ((Number) service.deleteDraftJob(100L, positionId).get("posId")).longValue());

        assertEquals(0, jdbc.queryForObject("select count(*) from t_sch_slot where slt_position_id = ?",
                Integer.class, positionId));
        assertEquals(1, jdbc.queryForObject("select count(*) from t_sch_slot where slt_position_id = ?",
                Integer.class, otherPositionId));
    }

    @Test
    void refusesDeletionForOtherCompanyJob()
    {
        long positionId = position(0);
        ServiceException error = assertThrows(ServiceException.class, () -> service.deleteDraftJob(100L, positionId + 999));
        assertTrue(error.getMessage().contains("不存在"));
        assertEquals(1, jdbc.queryForObject("select count(*) from t_pos where pos_id = ?", Integer.class, positionId));
    }
}
