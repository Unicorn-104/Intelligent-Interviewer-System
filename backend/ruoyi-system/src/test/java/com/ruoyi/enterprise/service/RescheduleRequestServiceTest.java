package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.nio.file.Files;
import java.nio.file.Path;
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
import com.github.pagehelper.PageHelper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.InterviewScheduleMapper;
import com.ruoyi.enterprise.mapper.RescheduleRequestMapper;
import com.ruoyi.enterprise.service.impl.InterviewScheduleServiceImpl;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;

/** 仅随机 H2 内存库与合成数据；不加载应用数据源、不连接业务数据库。 */
public class RescheduleRequestServiceTest
{
    private JdbcTemplate jdbc;
    private RescheduleRequestService service;
    private InterviewScheduleServiceImpl schedules;
    private RescheduleRequestMapper requests;
    private DashboardMapper companies;
    private DriverManagerDataSource dataSource;
    public static String dateFormat(Timestamp time, String pattern)
    {
        return time == null ? null : time.toLocalDateTime().format(DateTimeFormatter.ofPattern(
                pattern.contains("%s") ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd HH:mm"));
    }
    private <T> T transactional(T target, Class<T> type)
    {
        ProxyFactory factory = new ProxyFactory(target);
        factory.setProxyTargetClass(true);
        factory.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(dataSource),
                new AnnotationTransactionAttributeSource()));
        return type.cast(factory.getProxy());
    }
    @BeforeEach void setup() throws Exception
    {
        dataSource = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=5000", "sa", "");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("CREATE ALIAS date_format FOR 'com.ruoyi.enterprise.service.RescheduleRequestServiceTest.dateFormat'");
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
            "insert into sys_user values(19,'0','合成面试官'),(20,'0','合成面试官二'),(101,'0','合成候选人'),(102,'0','合成候选人二'),(9,'0','合成HR')",
            "insert into t_tal(tal_id,tal_user_id) values(11,101),(12,102)",
            "insert into t_pos values(7,1,'合成岗位',1),(8,2,'另一企业岗位',2)",
            "insert into t_process_instance values(11,7),(12,7)",
            "insert into t_cmp_binding values(1,19,1),(1,20,1)",
            "insert into t_process_stage values(31,1,'在线笔试',1,1),(32,1,'技术面试',2,2)")) jdbc.execute(sql);
        Path directory = Path.of("").toAbsolutePath();
        while (directory != null && !Files.exists(directory.resolve("e-app/new.sql"))) directory = directory.getParent();
        assertNotNull(directory);
        String migration = Files.readString(directory.resolve("e-app/new.sql"))
                .split("-- BEGIN RESCHEDULE_REVIEW_20261023")[1].split("-- END RESCHEDULE_REVIEW_20261023")[0];
        String ddl = migration.substring(migration.indexOf("CREATE TABLE"));
        ddl = ddl.substring(0, ddl.indexOf(";") + 1).replaceAll("COMMENT '[^']*'", "")
                .replace(") STORED", ")").replaceAll("ENGINE=InnoDB DEFAULT CHARSET=utf8mb4", "");
        jdbc.execute(ddl);
        jdbc.execute(ddl); // 本段幂等执行，历史SQL不参与。
        var factory = new SqlSessionFactoryBean();
        factory.setDataSource(dataSource);
        var paging = new com.github.pagehelper.PageInterceptor();
        var pagingProperties = new java.util.Properties();
        pagingProperties.setProperty("helperDialect", "h2");
        paging.setProperties(pagingProperties);
        factory.setPlugins(paging);
        factory.setMapperLocations(new ClassPathResource("mapper/enterprise/InterviewScheduleMapper.xml"),
                new ClassPathResource("mapper/enterprise/RescheduleRequestMapper.xml"));
        var template = new SqlSessionTemplate(factory.getObject());
        var scheduleMapper = template.getMapper(InterviewScheduleMapper.class);
        requests = template.getMapper(RescheduleRequestMapper.class);
        companies = mock(DashboardMapper.class);
        when(companies.selectCompanyIdByUser(9L)).thenReturn(1L);
        when(companies.selectCompanyIdByUser(19L)).thenReturn(1L);
        when(companies.selectCompanyIdByUser(8L)).thenReturn(2L);
        var jobs = mock(EnterpriseJobMapper.class);
        when(jobs.selectJobById(7L,1L)).thenReturn(Map.of("posId",7L));
        var scheduleTarget = new InterviewScheduleServiceImpl();
        ReflectionTestUtils.setField(scheduleTarget,"scheduleMapper",scheduleMapper);
        ReflectionTestUtils.setField(scheduleTarget,"dashboardMapper",companies);
        ReflectionTestUtils.setField(scheduleTarget,"jobMapper",jobs);
        schedules = transactional(scheduleTarget, InterviewScheduleServiceImpl.class);
        service = buildService(requests, scheduleMapper);
    }
    private RescheduleRequestService buildService(RescheduleRequestMapper mapper, InterviewScheduleMapper scheduleMapper)
    {
        var target = new RescheduleRequestService();
        ReflectionTestUtils.setField(target,"requestMapper",mapper);
        ReflectionTestUtils.setField(target,"scheduleMapper",scheduleMapper);
        ReflectionTestUtils.setField(target,"dashboardMapper",companies);
        ReflectionTestUtils.setField(target,"scheduleService",schedules);
        return transactional(target, RescheduleRequestService.class);
    }
    private long appointment(long candidate, long interviewer, String time)
    {
        return ((Number)schedules.invite(9L,candidate,7L,null,interviewer,time,45).get("appointmentId")).longValue();
    }
    private long request(long appointment)
    {
        return ((Number)service.submit(101L,appointment,"2099-01-03 09:00","合成申请原因").get("requestId")).longValue();
    }
    @Test void submitUsesRealUserOwnershipSnapshotsAndDoesNotChangeAppointment()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00");
        long request = request(appointment);
        var row = requests.selectRequest(request,1L);
        assertEquals(101L, ((Number)row.get("requesterId")).longValue());
        assertEquals(11L, ((Number)row.get("candidateId")).longValue());
        assertEquals("2099-01-02 09:00:00", row.get("originalStartTime"));
        assertEquals("2099-01-03 09:45:00", row.get("newEndTime"));
        assertEquals("pending",row.get("status"));
        assertEquals("2099-01-02 09:00:00",requests.selectAppointment(appointment).get("startTime"));
        assertEquals(1,jdbc.queryForObject("select count(*) from t_sch_slot",Integer.class));
        assertThrows(ServiceException.class, () -> service.submit(11L,appointment,"2099-01-04 09:00","合成"));
        assertThrows(ServiceException.class, () -> service.submit(102L,appointment,"2099-01-04 09:00","合成"));
        assertThrows(ServiceException.class, () -> request(appointment));
    }
    @Test void approveChangesSlotAndPersistsDecisionAtomicallyAndIdempotently()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        var row = service.review(9L,request,"approved","合成通过说明");
        assertEquals("approved",row.get("status"));
        assertEquals(9L,((Number)row.get("reviewerId")).longValue());
        assertEquals("2099-01-03 09:00:00",requests.selectAppointment(appointment).get("startTime"));
        assertEquals(1,jdbc.queryForObject("select slt_status from t_sch_slot where slt_id=1",Integer.class));
        service.review(19L,request,"approved","不应覆盖原说明");
        assertEquals(2,jdbc.queryForObject("select count(*) from t_sch_slot",Integer.class));
        assertEquals("合成通过说明",requests.selectRequest(request,1L).get("reviewNote"));
        assertEquals(9L,((Number)requests.selectRequest(request,1L).get("reviewerId")).longValue());
        assertThrows(ServiceException.class, () -> service.review(9L,request,"rejected","不能反向审批"));
    }
    @Test void rejectRequiresReasonAndLeavesOriginalSlotUntouched()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        assertThrows(ServiceException.class, () -> service.review(9L,request,"rejected","  "));
        assertEquals("rejected",service.review(9L,request,"rejected","合成驳回原因").get("status"));
        assertEquals("2099-01-02 09:00:00",requests.selectAppointment(appointment).get("startTime"));
        assertEquals(1,jdbc.queryForObject("select count(*) from t_sch_slot",Integer.class));
        assertDoesNotThrow(() -> request(appointment));
    }
    @Test void companyScopeDoesNotFallBackToCompanyOneEvenForAdmin()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        assertThrows(ServiceException.class, () -> service.review(8L,request,"approved",null));
        assertThrows(ServiceException.class, () -> service.review(1L,request,"approved",null));
        assertNull(requests.selectRequest(request,2L));
        assertTrue(requests.selectCompanyRequests(2L,null).isEmpty());
        assertTrue(requests.selectOwnRequests(102L).isEmpty());
        assertEquals(1,requests.selectOwnRequests(101L).size());
        assertThrows(ServiceException.class, () -> service.list(1L,null,1,20));
    }
    @Test void conflictAtApprovalLeavesRequestPendingAndOldAppointmentReserved()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        appointment(12,19,"2099-01-03 09:00");
        assertThrows(ServiceException.class, () -> service.review(9L,request,"approved",null));
        assertEquals("pending",requests.selectRequest(request,1L).get("status"));
        assertEquals("2099-01-02 09:00:00",requests.selectAppointment(appointment).get("startTime"));
        assertEquals(2,jdbc.queryForObject("select count(*) from t_sch_slot",Integer.class));
    }
    @Test void changedOriginalScheduleCannotBeSilentlyOverwrittenButCanBeRejected()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        schedules.reschedule(9L,appointment,"2099-01-04 09:00",null,null);
        assertThrows(ServiceException.class, () -> service.review(9L,request,"approved",null));
        assertEquals("pending",requests.selectRequest(request,1L).get("status"));
        assertDoesNotThrow(() -> service.review(9L,request,"rejected","原安排已变化"));
    }
    @Test void failedDecisionPersistenceRollsBackAlreadyChangedAppointment()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        RescheduleRequestMapper failing = spy(requests);
        doReturn(0).when(failing).updateDecision(eq(request),eq(1L),eq(1),eq(9L),isNull());
        var scheduleMapper = mock(InterviewScheduleMapper.class);
        var rollbackService = buildService(failing,scheduleMapper);
        assertThrows(ServiceException.class, () -> rollbackService.review(9L,request,"approved",null));
        assertEquals("pending",requests.selectRequest(request,1L).get("status"));
        assertEquals("2099-01-02 09:00:00",requests.selectAppointment(appointment).get("startTime"));
        assertEquals(1,jdbc.queryForObject("select count(*) from t_sch_slot",Integer.class));
    }
    @Test void concurrentApprovalsOnlyMoveAppointmentOnce() throws Exception
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        var pool = Executors.newFixedThreadPool(2);
        try
        {
            Callable<String> action = () -> String.valueOf(service.review(9L,request,"approved",null).get("status"));
            for (var result : pool.invokeAll(List.of(action,action))) assertEquals("approved",result.get());
        }
        finally { pool.shutdownNow(); }
        assertEquals(2,jdbc.queryForObject("select count(*) from t_sch_slot",Integer.class));
    }
    @Test void concurrentSubmissionsCreateOnlyOnePendingRecord() throws Exception
    {
        long appointment = appointment(11,19,"2099-01-02 09:00");
        var pool = Executors.newFixedThreadPool(2);
        try
        {
            Callable<Boolean> action = () -> { try { request(appointment); return true; }
                catch (ServiceException ex) { return false; } };
            var results = pool.invokeAll(List.of(action,action));
            assertNotEquals(results.get(0).get(),results.get(1).get());
        }
        finally { pool.shutdownNow(); }
        assertEquals(1,requests.countPending(appointment));
    }
    @Test void validatesTimeReasonPaginationAndStatuses()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00");
        for (String time : List.of("2020-01-01 10:00","2099-02-30 10:00","2099-01-02 09:00","2099-01-03 09:00:30"))
            assertThrows(ServiceException.class, () -> service.submit(101L,appointment,time,"合成"));
        for (String reason : List.of(" ","长".repeat(501),"非法\u0000原因"))
            assertThrows(ServiceException.class, () -> service.submit(101L,appointment,"2099-01-03 09:00",reason));
        assertThrows(ServiceException.class, () -> service.list(9L,"unknown",1,20));
        assertThrows(ServiceException.class, () -> service.list(9L,null,0,20));
        assertThrows(ServiceException.class, () -> service.own(101L,1,101));
        try { service.list(9L,"pending",1,20); }
        finally { PageHelper.clearPage(); }
    }
    @Test void cancelledAppointmentCannotBeApprovedButCanBeClosedByRejection()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        schedules.updateStatus(9L,appointment,2);
        assertThrows(ServiceException.class, () -> service.review(9L,request,"approved",null));
        assertEquals("rejected",service.review(9L,request,"rejected","面试已取消").get("status"));
    }
    @Test void requesterCannotApproveOwnRequestEvenWhenBoundToEnterprise()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        when(companies.selectCompanyIdByUser(101L)).thenReturn(1L);
        assertThrows(ServiceException.class, () -> service.review(101L,request,"approved",null));
        assertEquals("pending",requests.selectRequest(request,1L).get("status"));
    }
    @Test void approvalReusesCandidateConflictAndStageOrderingRules()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        appointment(11,20,"2099-01-03 09:00");
        assertThrows(ServiceException.class, () -> service.review(9L,request,"approved",null));
        service.review(9L,request,"rejected","存在候选人时间冲突");
        var stages = schedules.inviteStages(9L,12L,7L,List.of(
            Map.of("stageId",31,"interviewerId",19,"startTime","2099-02-01 09:00","durationMin",30),
            Map.of("stageId",32,"interviewerId",19,"startTime","2099-02-01 10:00","durationMin",30)));
        long stageAppointment = ((Number)stages.get(0).get("appointmentId")).longValue();
        var stageRequest = service.submit(102L,stageAppointment,"2099-02-02 09:00","合成调整阶段申请");
        assertThrows(ServiceException.class, () -> service.review(9L,
                ((Number)stageRequest.get("requestId")).longValue(),"approved",null));
    }
    @Test void serverPaginatesAndFiltersBeforeReturningRows()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        service.review(9L,request,"rejected","合成历史");
        for (int i=0;i<21;i++) jdbc.update("insert into t_sch_reschedule_request "
                + "(rsr_appointment_id,rsr_company_id,rsr_candidate_id,rsr_requester_id,rsr_original_start,"
                + "rsr_original_end,rsr_original_interviewer_id,rsr_new_start,rsr_new_end,rsr_reason,rsr_status) "
                + "select rsr_appointment_id,rsr_company_id,rsr_candidate_id,rsr_requester_id,rsr_original_start,"
                + "rsr_original_end,rsr_original_interviewer_id,rsr_new_start,rsr_new_end,rsr_reason,rsr_status "
                + "from t_sch_reschedule_request where rsr_id=?",request);
        var page = service.list(9L,"rejected",2,20);
        assertEquals(2,page.size());
        assertEquals(22,new com.github.pagehelper.PageInfo<>(page).getTotal());
        assertTrue(service.list(9L,"pending",1,20).isEmpty());
        assertEquals(2,service.own(101L,2,20).size());
    }
    @Test void databaseUniqueGuardRejectsBypassedDuplicatePendingInsert()
    {
        long appointment = appointment(11,19,"2099-01-02 09:00"), request = request(appointment);
        Map<String,Object> duplicate = new java.util.LinkedHashMap<>(requests.selectRequest(request,1L));
        duplicate.remove("requestId");
        assertThrows(org.springframework.dao.DuplicateKeyException.class, () -> requests.insertRequest(duplicate));
        assertEquals(1,requests.countPending(appointment));
    }

}
