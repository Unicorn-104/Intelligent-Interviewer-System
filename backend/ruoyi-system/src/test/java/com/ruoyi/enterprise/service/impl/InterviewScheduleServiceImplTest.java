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
import com.ruoyi.enterprise.mapper.ScreeningMapper;
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
            "create table t_process_instance(pin_candidate_id bigint, pin_position_id bigint, pin_status int default 0)",
            "create table t_cmp_binding(bnd_company_id bigint, bnd_user_id bigint, bnd_status int)",
            "create table t_process_stage(psg_id bigint primary key, psg_template_id bigint, psg_name varchar(100), psg_type int, psg_sort_order int, psg_interviewer_config_json varchar(2000))",
            "create table t_int_session(ses_id bigint, ses_appointment_id bigint, ses_candidate_id bigint, ses_position_id bigint, ses_status int)",
            "create table t_int_evaluation(evl_session_id bigint, evl_hr_status int)",
            "create table t_tal_status_log(tsl_id bigint auto_increment primary key, tsl_candidate_id bigint, tsl_from_status int, tsl_to_status int, tsl_created_at timestamp)",
            "create table t_app_record(app_id bigint auto_increment primary key, app_candidate_id bigint, app_position_id bigint, app_status int, app_updated_at timestamp)",
            "create table t_sch_slot(slt_id bigint auto_increment primary key, slt_interviewer_id bigint, slt_position_id bigint, slt_start_time timestamp, slt_end_time timestamp, slt_status int, slt_updated_at timestamp)",
            "create table t_sch_appointment(apt_id bigint auto_increment primary key, apt_candidate_id bigint, apt_position_id bigint, apt_stage_id bigint, apt_stage_name varchar(100), apt_stage_type int, apt_stage_order int, apt_interviewer_id bigint, apt_slot_id bigint, apt_start_time timestamp, apt_end_time timestamp, apt_status int, apt_notified int default 0, apt_meeting_url varchar(255), apt_room_id varchar(100), apt_updated_at timestamp)",
            "insert into sys_user values(19,'0','面试官'),(20,'0','面试官二'),(11,'0','候选人'),(12,'0','候选人二')",
            "insert into t_tal(tal_id,tal_user_id) values(11,11),(12,12)",
            "insert into t_pos values(7,1,'合成岗位',1)",
            "insert into t_process_instance values(11,7,0),(12,7,0)",
            "insert into t_cmp_binding values(1,19,1),(1,20,1)",
            "insert into t_app_record(app_candidate_id,app_position_id,app_status) values(11,7,1),(12,7,1)",
            "insert into t_process_stage values(31,1,'在线笔试',1,1,'{\"duration\":30}'),(32,1,'技术面试',2,2,'{\"duration\":60}')")) jdbc.execute(sql);
        var factory = new SqlSessionFactoryBean();
        factory.setDataSource(ds);
        factory.setMapperLocations(new ClassPathResource("mapper/enterprise/InterviewScheduleMapper.xml"));
        mapper = new SqlSessionTemplate(factory.getObject()).getMapper(InterviewScheduleMapper.class);
        var target = new InterviewScheduleServiceImpl();
        var companyMapper = mock(DashboardMapper.class);
        when(companyMapper.selectCompanyIdByUser(1L)).thenReturn(1L);
        var jobs = mock(EnterpriseJobMapper.class);
        when(jobs.selectJobById(7L,1L)).thenReturn(Map.of("posId",7L));
        when(jobs.selectJobById(8L,1L)).thenReturn(Map.of("posId",8L));
        ReflectionTestUtils.setField(target,"scheduleMapper",mapper);
        ReflectionTestUtils.setField(target,"dashboardMapper",companyMapper);
        ReflectionTestUtils.setField(target,"jobMapper",jobs);
        ReflectionTestUtils.setField(target,"screeningMapper",mock(ScreeningMapper.class));
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
        // 阶段31配置时长为30分钟：客户端传入60也被忽略，以阶段配置为准。
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",60);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        assertEquals("2099-01-02 09:30",mapper.selectAppointmentById(id).get("endTime"));
        var moved = service.reschedule(1L,id,"2099-01-02 09:15",null,null);
        assertEquals("2099-01-02 09:45:00",moved.get("endTime"));
        var resized = service.reschedule(1L,id,"2099-01-02 09:15",90,20L);
        assertEquals("2099-01-02 10:45:00",resized.get("endTime"));
        assertEquals(20L,resized.get("interviewerId"));
        assertEquals(2,jdbc.queryForObject("select count(*) from t_sch_slot where slt_status=1",Integer.class));
        assertEquals(31L,((Number)mapper.selectAppointmentById(id).get("stageId")).longValue());
    }
    @Test
    void conflictOnMoveKeepsOriginalAppointmentAndOccupiedSlot()
    {
        // 阶段31配置时长30分钟：预约09:00-09:30；候选人12占用10:00-11:00。
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",60);
        service.invite(1L,12L,7L,null,19L,"2099-01-02 10:00",60);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        // 改期到09:45（09:45-10:15）与10:00-11:00重叠，应被拒绝且原预约不变。
        assertThrows(ServiceException.class,() -> service.reschedule(1L,id,"2099-01-02 09:45",null,null));
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
    void stagedInviteUsesStageConfiguredDurationAndRejectsMissingConfig()
    {
        // 跨天排期：23:40 + 阶段配置30分钟 → 次日00:10；客户端伪造999分钟被忽略。
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-03 23:40",999);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        assertEquals("2099-01-04 00:10",mapper.selectAppointmentById(id).get("endTime"));
        assertEquals("2099-01-03 23:40",mapper.selectAppointmentById(id).get("startTime"));
        // 未配置时长的阶段拒绝排期，客户端时长不作为依据。
        jdbc.update("insert into t_process_stage values(33,1,'未配置时长阶段',3,3,null)");
        ServiceException error = assertThrows(ServiceException.class,
                () -> service.invite(1L,12L,7L,33L,19L,"2099-01-04 09:00",45));
        assertTrue(error.getMessage().contains("未配置面试时长"));
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

    // ==================== 取消预约：时段释放与状态恢复 ====================

    /** 邀约后补写状态日志，模拟数据库触发器记录的「进入面试中之前」的流程状态。 */
    private void logTal(int candidate, int from, int to)
    {
        jdbc.update("insert into t_tal_status_log(tsl_candidate_id,tsl_from_status,tsl_to_status) values(?,?,?)",
                candidate, from, to);
    }
    private int talStatus(int candidate)
    {
        return jdbc.queryForObject("select tal_status from t_tal where tal_id=" + candidate, Integer.class);
    }
    private int appStatus(int candidate, int position)
    {
        return jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=" + candidate
                + " and app_position_id=" + position, Integer.class);
    }
    private int slotStatus(long slotId)
    {
        return jdbc.queryForObject("select slt_status from t_sch_slot where slt_id=" + slotId, Integer.class);
    }
    /** 投递推进为已约面 + 候选人推进为面试中，模拟真实邀约的联动（screeningMapper 在本测试为 mock）。 */
    private void advanceToInvited(int candidate)
    {
        jdbc.update("update t_tal set tal_status=2 where tal_id=" + candidate);
        jdbc.update("update t_app_record set app_status=3 where app_candidate_id=" + candidate);
    }
    private Map<String, Object> cancel(long appointmentId)
    {
        return service.updateStatus(1L, appointmentId, 2);
    }

    @Test
    void cancelSingleAppointmentReleasesSlotAndRestoresStatuses()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        long slotId = ((Number)appointment.get("slotId")).longValue();
        logTal(11, 1, 2);
        advanceToInvited(11);
        var result = cancel(id);
        assertEquals(true, result.get("slotReleased"));
        assertEquals(true, result.get("candidateStatusRestored"));
        assertEquals(true, result.get("applicationStatusRestored"));
        assertEquals(0, result.get("remainingAppointments"));
        assertEquals(2, mapper.selectAppointmentById(id).get("status"));
        assertEquals(1, slotStatus(slotId));
        assertEquals(1, talStatus(11));
        assertEquals(1, appStatus(11, 7));
    }

    @Test
    void cancelOneStageKeepsOtherStageAndStatuses()
    {
        var batch = service.inviteStages(1L,11L,7L,List.of(
                stage(31,19,"2099-01-02 09:00",30), stage(32,20,"2099-01-02 10:00",60)));
        long firstId = ((Number)batch.get(0).get("appointmentId")).longValue();
        long secondId = ((Number)batch.get(1).get("appointmentId")).longValue();
        long firstSlot = ((Number)batch.get(0).get("slotId")).longValue();
        long secondSlot = ((Number)batch.get(1).get("slotId")).longValue();
        logTal(11, 1, 2);
        advanceToInvited(11);
        var result = cancel(firstId);
        assertEquals(true, result.get("slotReleased"));
        assertEquals(false, result.get("candidateStatusRestored"));
        assertEquals(1, result.get("remainingAppointments"));
        assertEquals(1, slotStatus(firstSlot));
        assertEquals(0, slotStatus(secondSlot));
        assertEquals(2, talStatus(11));
        assertEquals(3, appStatus(11, 7));
        assertEquals(0, mapper.selectAppointmentById(secondId).get("status"));
    }

    @Test
    void cancelLastValidAppointmentRestoresAfterEarlierCancelled()
    {
        var batch = service.inviteStages(1L,11L,7L,List.of(
                stage(31,19,"2099-01-02 09:00",30), stage(32,20,"2099-01-02 10:00",60)));
        long firstId = ((Number)batch.get(0).get("appointmentId")).longValue();
        long secondId = ((Number)batch.get(1).get("appointmentId")).longValue();
        logTal(11, 1, 2);
        advanceToInvited(11);
        cancel(firstId);
        var result = cancel(secondId);
        assertEquals(true, result.get("candidateStatusRestored"));
        assertEquals(0, result.get("remainingAppointments"));
        // 两个阶段都已取消，最后一条取消后才恢复状态
        assertEquals(1, talStatus(11));
        assertEquals(1, appStatus(11, 7));
    }

    @Test
    void cancelKeepsStatusWhenStageAlreadyCompleted()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        logTal(11, 1, 2);
        advanceToInvited(11);
        jdbc.update("insert into t_int_session(ses_id,ses_candidate_id,ses_position_id,ses_status) values(1,11,7,2)");
        var result = cancel(id);
        assertEquals(true, result.get("slotReleased"));
        assertEquals(false, result.get("candidateStatusRestored"));
        assertEquals(false, result.get("applicationStatusRestored"));
        assertEquals(2, talStatus(11));
        assertEquals(3, appStatus(11, 7));
    }

    @Test
    void cancelKeepsCandidateStatusWhenOtherPositionStillHasValidAppointment()
    {
        // 候选人同时面试岗位7与岗位8：取消岗位7最后一个预约，候选人状态不回退（岗位8仍有效），
        // 岗位7投递状态按岗位粒度回退。
        jdbc.update("insert into t_pos values(8,1,'第二岗位',1)");
        jdbc.update("insert into t_process_instance values(11,8,0)");
        jdbc.update("insert into t_app_record(app_candidate_id,app_position_id,app_status) values(11,8,1)");
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        long slotId = ((Number)appointment.get("slotId")).longValue();
        service.invite(1L,11L,8L,null,20L,"2099-01-03 10:00",45);
        logTal(11, 1, 2);
        advanceToInvited(11);
        var result = cancel(id);
        assertEquals(true, result.get("slotReleased"));
        assertEquals(false, result.get("candidateStatusRestored"));
        assertEquals(true, result.get("applicationStatusRestored"));
        assertEquals(1, slotStatus(slotId));
        assertEquals(2, talStatus(11));
        assertEquals(1, appStatus(11, 7));
        assertEquals(3, appStatus(11, 8));
    }

    @Test
    void cancelKeepsStatusWhenProcessInstanceNotActive()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        logTal(11, 1, 2);
        advanceToInvited(11);
        jdbc.update("update t_process_instance set pin_status=1 where pin_candidate_id=11 and pin_position_id=7");
        var result = cancel(id);
        assertEquals(false, result.get("candidateStatusRestored"));
        assertEquals(2, talStatus(11));
        assertEquals(3, appStatus(11, 7));
    }

    @Test
    void cancelDoesNotRegressExamPassedCandidate()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        // 笔试通过直接进入「面试中」，日志来源为待笔试(5)：不能回退到待笔试
        logTal(11, 5, 2);
        advanceToInvited(11);
        var result = cancel(id);
        assertEquals(false, result.get("candidateStatusRestored"));
        assertEquals(false, result.get("applicationStatusRestored"));
        assertEquals(2, talStatus(11));
        assertEquals(3, appStatus(11, 7));
    }

    @Test
    void cancelWithoutStatusLogKeepsStatusesUnchanged()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        advanceToInvited(11);
        var result = cancel(id);
        assertEquals(true, result.get("slotReleased"));
        assertEquals(false, result.get("candidateStatusRestored"));
        assertEquals(2, talStatus(11));
        assertEquals(3, appStatus(11, 7));
    }

    @Test
    void repeatCancelIsIdempotent()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        long slotId = ((Number)appointment.get("slotId")).longValue();
        logTal(11, 1, 2);
        advanceToInvited(11);
        cancel(id);
        var again = cancel(id);
        assertEquals(2, again.get("status"));
        assertEquals(false, again.get("slotReleased"));
        assertEquals(false, again.get("candidateStatusRestored"));
        assertEquals(1, slotStatus(slotId));
        assertEquals(1, talStatus(11));
        assertEquals(1, appStatus(11, 7));
    }

    @Test
    void cancelCompletedAppointmentRejected()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        jdbc.update("update t_sch_appointment set apt_status=3 where apt_id=" + id);
        assertThrows(ServiceException.class, () -> cancel(id));
        assertThrows(ServiceException.class, () -> service.updateStatus(1L, id, 1));
        assertEquals(3, mapper.selectAppointmentById(id).get("status"));
    }

    @Test
    void confirmStillWorksAndRejectsCancelled()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        var confirmed = service.updateStatus(1L, id, 1);
        assertEquals(1, confirmed.get("status"));
        assertEquals(1, mapper.selectAppointmentById(id).get("status"));
        cancel(id);
        assertThrows(ServiceException.class, () -> service.updateStatus(1L, id, 1));
    }

    @Test
    void rescheduleRejectedAfterCancel()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        cancel(id);
        assertThrows(ServiceException.class, () -> service.reschedule(1L, id, "2099-01-03 09:00", null, null));
    }

    @Test
    void cancelConcurrentWithInviteEndsConsistent() throws Exception
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",30);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        long slotId = ((Number)appointment.get("slotId")).longValue();
        logTal(11, 1, 2);
        advanceToInvited(11);
        var executor = Executors.newFixedThreadPool(2);
        try {
            Callable<Boolean> cancel = () -> { try { service.updateStatus(1L, id, 2); return true; } catch(ServiceException e) { return false; } };
            Callable<Boolean> invite = () -> { try { service.invite(1L,11L,7L,32L,20L,"2099-01-02 10:00",45); return true; } catch(ServiceException e) { return false; } };
            var results = executor.invokeAll(List.of(cancel, invite));
            // 候选人行锁串行化两个事务：任一顺序都不得双写或漏释放
            assertTrue(results.stream().allMatch(f -> {
                try { return f.get(); } catch (Exception e) { return false; }
            }));
            assertEquals(2, mapper.selectAppointmentById(id).get("status"));
            assertEquals(1, slotStatus(slotId));
            assertEquals(1, jdbc.queryForObject(
                    "select count(*) from t_sch_appointment where apt_status in (0,1)", Integer.class));
            assertEquals(2, talStatus(11));
        } finally { executor.shutdownNow(); }
    }

    // ==================== 提醒状态：改期重置与显式重置 ====================

    @Test
    void rescheduleResetsRemindFlagForNewTime()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        jdbc.update("update t_sch_appointment set apt_notified=1 where apt_id=" + id);
        service.reschedule(1L, id, "2099-01-02 09:15", null, null);
        assertEquals(0, jdbc.queryForObject("select apt_notified from t_sch_appointment where apt_id=" + id, Integer.class));
    }

    @Test
    void resetRemindStatusResetsProcessedFlagOnly()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        jdbc.update("update t_sch_appointment set apt_notified=1 where apt_id=" + id);
        var result = service.resetRemindStatus(1L, id);
        assertEquals(0, jdbc.queryForObject("select apt_notified from t_sch_appointment where apt_id=" + id, Integer.class));
        assertTrue(String.valueOf(result.get("message")).contains("已重置"));
        // 发送中(2)的认领不受重置影响
        jdbc.update("update t_sch_appointment set apt_notified=2 where apt_id=" + id);
        service.resetRemindStatus(1L, id);
        assertEquals(2, jdbc.queryForObject("select apt_notified from t_sch_appointment where apt_id=" + id, Integer.class));
    }

    @Test
    void resetRemindStatusRejectsCancelledCompletedAndStarted()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        cancel(id);
        assertThrows(ServiceException.class, () -> service.resetRemindStatus(1L, id));
        jdbc.update("update t_sch_appointment set apt_status=3 where apt_id=" + id);
        assertThrows(ServiceException.class, () -> service.resetRemindStatus(1L, id));
        // 已开始的面试不可重置（邀约接口强制未来时间，直接插入历史有效预约）
        jdbc.update("insert into t_sch_appointment(apt_candidate_id,apt_position_id,apt_stage_id,"
                + "apt_interviewer_id,apt_start_time,apt_end_time,apt_status) values"
                + "(12,7,32,20,'2020-01-02 09:00','2020-01-02 10:00',1)");
        long startedId = jdbc.queryForObject("select max(apt_id) from t_sch_appointment", Long.class);
        assertThrows(ServiceException.class, () -> service.resetRemindStatus(1L, startedId));
    }

    // ==================== 会议重新发起前的统一取消入口（cancelForRelaunch） ====================

    private Map<String, Object> relaunchCancel(long appointmentId)
    {
        return service.cancelForRelaunch(1L, appointmentId);
    }

    @Test
    void relaunchCancelReleasesSlotAndRestoresStatuses()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        long slotId = ((Number)appointment.get("slotId")).longValue();
        logTal(11, 1, 2);
        advanceToInvited(11);
        var result = relaunchCancel(id);
        assertEquals("已取消该面试安排，面试官时段已释放", result.get("message"));
        assertEquals(true, result.get("slotReleased"));
        assertEquals(true, result.get("candidateStatusRestored"));
        assertEquals(1, slotStatus(slotId));
        assertEquals(1, talStatus(11));
        assertEquals(1, appStatus(11, 7));
    }

    @Test
    void relaunchCancelSkipsCancelledWithoutSideEffects()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        cancel(id);
        var result = relaunchCancel(id);
        assertEquals("该面试安排已取消，已跳过", result.get("message"));
        assertEquals(false, result.get("slotReleased"));
        assertEquals(false, result.get("candidateStatusRestored"));
        assertEquals(2, mapper.selectAppointmentById(id).get("status"));
    }

    @Test
    void relaunchCancelSkipsCompletedWithoutSideEffects()
    {
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        long slotId = ((Number)appointment.get("slotId")).longValue();
        jdbc.update("update t_sch_appointment set apt_status=3 where apt_id=" + id);
        logTal(11, 1, 2);
        advanceToInvited(11);
        var result = relaunchCancel(id);
        assertEquals("该面试安排已完成，已跳过", result.get("message"));
        assertEquals(false, result.get("slotReleased"));
        // 已完成预约的时段保持占用，状态不回退
        assertEquals(0, slotStatus(slotId));
        assertEquals(2, talStatus(11));
        assertEquals(3, appStatus(11, 7));
    }

    @Test
    void relaunchCancelSkipsMissingAppointment()
    {
        var result = relaunchCancel(9999L);
        assertEquals("预约记录不存在，已跳过", result.get("message"));
        assertEquals(false, result.get("slotReleased"));
    }

    @Test
    void relaunchCancelDoesNotRegressOtherPositionInterview()
    {
        // 岗位8仍有有效预约时，取消岗位7的旧预约只恢复岗位7投递，候选人状态不回退
        jdbc.update("insert into t_pos values(8,1,'第二岗位',1)");
        jdbc.update("insert into t_process_instance values(11,8,0)");
        jdbc.update("insert into t_app_record(app_candidate_id,app_position_id,app_status) values(11,8,1)");
        var appointment = service.invite(1L,11L,7L,31L,19L,"2099-01-02 09:00",45);
        long id = ((Number)appointment.get("appointmentId")).longValue();
        service.invite(1L,11L,8L,null,20L,"2099-01-03 10:00",45);
        logTal(11, 1, 2);
        advanceToInvited(11);
        var result = relaunchCancel(id);
        assertEquals(false, result.get("candidateStatusRestored"));
        assertEquals(true, result.get("applicationStatusRestored"));
        assertEquals(2, talStatus(11));
        assertEquals(1, appStatus(11, 7));
        assertEquals(3, appStatus(11, 8));
    }
}
