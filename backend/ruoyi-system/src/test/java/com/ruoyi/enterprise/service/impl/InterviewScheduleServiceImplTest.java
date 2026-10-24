package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.sql.Timestamp;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.InterviewScheduleMapper;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;

public class InterviewScheduleServiceImplTest
{
    private JdbcTemplate jdbc;
    private InterviewScheduleServiceImpl service;
    private InterviewScheduleMapper mapper;
    public static String dateFormat(Timestamp time, String pattern)
    {
        return time == null ? null : time.toLocalDateTime().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"));
    }
    @BeforeEach
    void setup() throws Exception
    {
        var ds = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=5000", "sa", "");
        jdbc = new JdbcTemplate(ds);
        jdbc.execute("CREATE ALIAS date_format FOR 'com.ruoyi.enterprise.service.impl.InterviewScheduleServiceImplTest.dateFormat'");
        for (String sql : List.of(
            "create table sys_user(user_id bigint primary key, status varchar(1), nick_name varchar(100))",
            "create table t_tal(tal_id bigint primary key, tal_user_id bigint, tal_status int default 0, tal_updated_at timestamp)",
            "create table t_pos(pos_id bigint primary key, pos_company_id bigint, pos_title varchar(100), pos_process_template_id bigint)",
            "create table t_process_instance(pin_candidate_id bigint, pin_position_id bigint)",
            "create table t_cmp_binding(bnd_company_id bigint, bnd_user_id bigint, bnd_status int)",
            "create table t_process_stage(psg_id bigint primary key, psg_template_id bigint, psg_name varchar(100), psg_type int, psg_sort_order int)",
            "create table t_int_session(ses_id bigint, ses_appointment_id bigint)",
            "create table t_sch_slot(slt_id bigint auto_increment primary key, slt_interviewer_id bigint, slt_position_id bigint, slt_start_time timestamp, slt_end_time timestamp, slt_status int, slt_updated_at timestamp)",
            "create table t_sch_appointment(apt_id bigint auto_increment primary key, apt_candidate_id bigint, apt_position_id bigint, apt_stage_id bigint, apt_stage_name varchar(100), apt_stage_type int, apt_stage_order int, apt_interviewer_id bigint, apt_slot_id bigint, apt_start_time timestamp, apt_end_time timestamp, apt_status int, apt_meeting_url varchar(255), apt_room_id varchar(100), apt_updated_at timestamp)",
            "insert into sys_user values(19,'0','面试官'),(20,'0','面试官二'),(11,'0','候选人'),(12,'0','候选人二')",
            "insert into t_tal(tal_id,tal_user_id) values(11,11),(12,12)",
            "insert into t_pos values(7,1,'合成岗位',1)",
            "insert into t_process_instance values(11,7),(12,7)",
            "insert into t_cmp_binding values(1,19,1),(1,20,1)",
            "insert into t_process_stage values(31,1,'在线笔试',1,1),(32,1,'技术面试',2,2)")) jdbc.execute(sql);
        var factory = new SqlSessionFactoryBean();
        factory.setDataSource(ds);
        factory.setMapperLocations(new ClassPathResource("mapper/enterprise/InterviewScheduleMapper.xml"));
        mapper = new SqlSessionTemplate(factory.getObject()).getMapper(InterviewScheduleMapper.class);
        var target = new InterviewScheduleServiceImpl();
        var companyMapper = mock(DashboardMapper.class);
        when(companyMapper.selectCompanyIdByUser(1L)).thenReturn(1L);
        var jobs = mock(EnterpriseJobMapper.class);
        when(jobs.selectJobById(7L,1L)).thenReturn(Map.of("posId",7L));
        ReflectionTestUtils.setField(target,"scheduleMapper",mapper);
        ReflectionTestUtils.setField(target,"dashboardMapper",companyMapper);
        ReflectionTestUtils.setField(target,"jobMapper",jobs);
        var proxy = new ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(ds), new AnnotationTransactionAttributeSource()));
        service = (InterviewScheduleServiceImpl) proxy.getProxy();
    }
    private Map<String,Object> stage(long id, long interviewer, String time, int duration)
    {
        return Map.of("stageId",id,"interviewerId",interviewer,"startTime",time,"durationMin",duration);
    }
    private int count(String table) { return jdbc.queryForObject("select count(*) from " + table,Integer.class); }
    @Test
    void batchPersistsIdsSnapshotsAndGeneratedKeys()
    {
        var results = service.inviteStages(1L,11L,7L,List.of(stage(31,19,"2099-01-02 09:00",30),stage(32,19,"2099-01-02 09:30",60)));
        assertEquals(2,count("t_sch_appointment"));
        assertNotEquals(results.get(0).get("appointmentId"),results.get(1).get("appointmentId"));
        var list = service.candidateAppointments(1L,11L,7L);
        assertEquals("在线笔试",list.get(0).get("stageName"));
        assertEquals(31L,((Number)list.get(0).get("stageId")).longValue());
        assertEquals("2099-01-02 10:30",list.get(1).get("endTime"));
    }
    @Test
    void laterConflictRollsBackEntireBatch()
    {
        service.invite(1L,12L,7L,null,20L,"2099-01-02 10:00",60);
        assertThrows(ServiceException.class, () -> service.inviteStages(1L,11L,7L,List.of(
            stage(31,19,"2099-01-02 09:00",30),stage(32,20,"2099-01-02 10:00",45))));
        assertEquals(1,count("t_sch_appointment"));
        assertEquals(1,count("t_sch_slot"));
    }
    @Test
    void rescheduleExcludesItselfPreservesDurationAndSupportsResize()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",60);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        var moved = service.reschedule(1L,id,"2099-01-02 09:15",null,null);
        assertEquals("2099-01-02 10:15:00",moved.get("endTime"));
        var resized = service.reschedule(1L,id,"2099-01-02 09:15",90,20L);
        assertEquals("2099-01-02 10:45:00",resized.get("endTime"));
        assertEquals(20L,resized.get("interviewerId"));
        assertEquals(2,jdbc.queryForObject("select count(*) from t_sch_slot where slt_status=1",Integer.class));
        assertEquals(31L,((Number)mapper.selectAppointmentById(id).get("stageId")).longValue());
    }
    @Test
    void conflictOnMoveKeepsOriginalAppointmentAndOccupiedSlot()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",60);
        service.invite(1L,12L,7L,null,19L,"2099-01-02 10:00",60);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        assertThrows(ServiceException.class,() -> service.reschedule(1L,id,"2099-01-02 09:30",null,null));
        assertEquals("2099-01-02 09:00",mapper.selectAppointmentById(id).get("startTime"));
        assertEquals(2,jdbc.queryForObject("select count(*) from t_sch_slot where slt_status=0",Integer.class));
    }
    @Test
    void rejectsOutOfOrderPastForeignAndDuplicateStages()
    {
        assertThrows(ServiceException.class,() -> service.inviteStages(1L,11L,7L,List.of(stage(31,19,"2099-01-02 10:00",60),stage(32,20,"2099-01-02 09:00",45))));
        assertEquals(0,count("t_sch_appointment"));
        assertThrows(ServiceException.class,() -> service.invite(1L,11L,7L,99L,19L,"2099-01-02 09:00",45));
        assertThrows(ServiceException.class,() -> service.invite(1L,11L,7L,31L,19L,"2020-01-02 09:00",45));
        service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        assertThrows(ServiceException.class,() -> service.invite(1L,11L,7L,31L,19L,"2099-01-02 11:00",45));
        assertEquals(1,count("t_sch_appointment"));
    }
    @Test
    void concurrentRequestsCannotDoubleBookInterviewer() throws Exception
    {
        var executor = Executors.newFixedThreadPool(2);
        try {
            Callable<Boolean> a = () -> { try { service.invite(1L,11L,7L,null,19L,"2099-01-02 09:00",45); return true; } catch(ServiceException e) { return false; } };
            Callable<Boolean> b = () -> { try { service.invite(1L,12L,7L,null,19L,"2099-01-02 09:00",45); return true; } catch(ServiceException e) { return false; } };
            var results = executor.invokeAll(List.of(a,b));
            assertNotEquals(results.get(0).get(),results.get(1).get());
            assertEquals(1,count("t_sch_appointment"));
        } finally { executor.shutdownNow(); }
    }
}
