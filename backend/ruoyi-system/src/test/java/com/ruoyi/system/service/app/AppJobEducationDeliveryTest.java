package com.ruoyi.system.service.app;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.support.TransactionTemplate;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.TalentPoolMapper;
import com.ruoyi.system.mapper.app.AppJobMapper;
import com.ruoyi.system.service.IEnterpriseJobService;
import com.ruoyi.system.service.app.impl.AppJobServiceImpl;

/** 实际 Mapper SQL 验证投递简历、人才档案与企业教育经历读取的一致性。 */
class AppJobEducationDeliveryTest
{
    private JdbcTemplate jdbc;
    private AppJobMapper jobs;
    private TalentPoolMapper talents;
    private AppJobServiceImpl service;
    private IEnterpriseJobService processes;
    private com.ruoyi.enterprise.service.EntResumeSnapshotService snapshots;
    private TransactionTemplate transaction;

    @BeforeEach void setup() throws Exception
    {
        var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(source);
        jdbc.execute("create table t_res_base(rbs_id bigint primary key,rbs_user_id bigint,rbs_status int)");
        jdbc.execute("create table t_pos(pos_id bigint primary key,pos_company_id bigint,pos_status int)");
        jdbc.execute("create table t_tal(tal_id bigint auto_increment primary key,tal_user_id bigint,"
                + "tal_company_id bigint,tal_resume_id bigint,tal_status int,tal_created_at timestamp,tal_updated_at timestamp)");
        jdbc.execute("create table t_app_record(app_id bigint auto_increment primary key,app_candidate_id bigint,"
                + "app_position_id bigint,app_resume_id bigint,app_matched_score int,app_status int,"
                + "app_created_at timestamp,app_updated_at timestamp)");
        jdbc.execute("create table t_res_education(edu_resume_id bigint,edu_school varchar(100),"
                + "edu_major varchar(100),edu_degree int,edu_start_date date,edu_end_date date)");
        jdbc.execute("CREATE ALIAS date_format FOR 'com.ruoyi.system.service.impl.ImServiceMessageTest.dateFormat'");
        jdbc.execute("insert into t_res_base values(51,17,1),(52,17,1),(53,18,1),(54,17,0)");
        jdbc.execute("insert into t_pos values(91,71,1),(92,71,1)");
        jdbc.execute("insert into t_tal(tal_id,tal_user_id,tal_company_id,tal_resume_id) values(31,17,71,51),(32,18,71,53)");
        jdbc.execute("insert into t_app_record(app_candidate_id,app_position_id,app_resume_id) values(31,92,51)");
        jdbc.execute("insert into t_res_education values(52,'Synthetic University','Computing',3,'2021-09-01','2025-06-01')");
        var factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setMapperLocations(new ClassPathResource("mapper/app/AppJobMapper.xml"),
                new ClassPathResource("mapper/enterprise/TalentPoolMapper.xml"));
        var session = new SqlSessionTemplate(factory.getObject());
        jobs = session.getMapper(AppJobMapper.class);
        talents = session.getMapper(TalentPoolMapper.class);
        service = new AppJobServiceImpl();
        processes = mock(IEnterpriseJobService.class);
        ReflectionTestUtils.setField(service, "jobMapper", jobs);
        ReflectionTestUtils.setField(service, "enterpriseJobService", processes);
        snapshots = mock(com.ruoyi.enterprise.service.EntResumeSnapshotService.class);
        ReflectionTestUtils.setField(service, "entResumeSnapshotService", snapshots);
        transaction = new TransactionTemplate(new DataSourceTransactionManager(source));
    }

    private void apply(long positionId, long resumeId)
    {
        transaction.executeWithoutResult(status -> service.apply(17L, positionId, resumeId));
    }

    private Long linkedResume()
    {
        return jdbc.queryForObject("select tal_resume_id from t_tal where tal_id=31", Long.class);
    }

    @Test void existingTalentReadsEducationFromNewApplicationResumeAndKeepsHistory()
    {
        apply(91, 52);
        assertEquals(52L, linkedResume());
        assertEquals(52L, jdbc.queryForObject("select app_resume_id from t_app_record where app_position_id=91", Long.class));
        assertEquals(51L, jdbc.queryForObject("select app_resume_id from t_app_record where app_position_id=92", Long.class));
        assertEquals(1, talents.selectEducation(linkedResume()).size());
        assertEquals("Synthetic University", talents.selectEducation(linkedResume()).get(0).get("SCHOOL"));
        verify(processes).ensureProcessInstance(71L, 31L, 91L);
        Long applicationId = jdbc.queryForObject(
                "select app_id from t_app_record where app_position_id=91", Long.class);
        verify(snapshots).createForApplication(applicationId, 17L, 31L, 71L, 91L, 52L);
    }

    @Test void duplicateApplicationCannotReplaceTheTalentResume()
    {
        assertThrows(ServiceException.class, () -> apply(92, 52));
        assertEquals(51L, linkedResume());
        assertEquals(1, jdbc.queryForObject("select count(*) from t_app_record", Integer.class));
        verifyNoInteractions(processes);
    }

    @Test void ownershipCompanyAndActiveStatusAreEnforcedByTheUpdateSql()
    {
        assertEquals(0, jobs.updateCandidateResume(32L, 17L, 71L, 52L));
        assertEquals(0, jobs.updateCandidateResume(31L, 17L, 99L, 52L));
        assertEquals(0, jobs.updateCandidateResume(31L, 17L, 71L, 53L));
        assertEquals(0, jobs.updateCandidateResume(31L, 17L, 71L, 54L));
        assertThrows(ServiceException.class, () -> apply(91, 53));
        assertEquals(51L, linkedResume());
    }

    @Test void processFailureRollsBackApplicationAndTalentResumeTogether()
    {
        when(processes.ensureProcessInstance(71L, 31L, 91L)).thenThrow(new ServiceException("synthetic failure"));
        assertThrows(ServiceException.class, () -> apply(91, 52));
        assertEquals(51L, linkedResume());
        assertEquals(0, jdbc.queryForObject("select count(*) from t_app_record where app_position_id=91", Integer.class));
    }

    @Test void snapshotFailureRollsBackApplicationAndTalentResumeTogether()
    {
        when(snapshots.createForApplication(anyLong(), eq(17L), eq(31L), eq(71L), eq(91L), eq(52L)))
                .thenThrow(new ServiceException("synthetic snapshot failure"));
        assertThrows(ServiceException.class, () -> apply(91, 52));
        assertEquals(51L, linkedResume());
        assertEquals(0, jdbc.queryForObject("select count(*) from t_app_record where app_position_id=91", Integer.class));
        verifyNoInteractions(processes);
    }
}
