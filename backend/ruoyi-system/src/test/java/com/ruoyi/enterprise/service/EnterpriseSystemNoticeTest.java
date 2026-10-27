package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
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
import com.ruoyi.enterprise.mapper.EnterpriseSystemNoticeMapper;
import com.ruoyi.system.mapper.DashboardMapper;

/** 只使用随机H2与合成事件，真实Mapper SQL和事务参与验证。 */
public class EnterpriseSystemNoticeTest
{
    private JdbcTemplate jdbc;
    private EnterpriseSystemNoticeService service;
    private EnterpriseSystemNoticeMapper mapper;
    private DashboardMapper companies;
    private LocalDateTime now;
    public static String dateFormat(Timestamp time,String pattern) {
        return time.toLocalDateTime().format(DateTimeFormatter.ofPattern("yyyyMMddHHmm"));
    }
    @BeforeEach void setup() throws Exception {
        var ds=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=5000","sa","");
        jdbc=new JdbcTemplate(ds);
        jdbc.execute("CREATE ALIAS date_format FOR 'com.ruoyi.enterprise.service.EnterpriseSystemNoticeTest.dateFormat'");
        for(String sql:List.of(
            "create table sys_user(user_id bigint primary key,nick_name varchar(100),status varchar(1),del_flag varchar(1))",
            "create table t_cmp_binding(bnd_company_id bigint,bnd_user_id bigint,bnd_status int)",
            "create table t_pos(pos_id bigint primary key,pos_title varchar(100),pos_company_id bigint)",
            "create table t_tal(tal_id bigint primary key,tal_user_id bigint)",
            "create table t_app_record(app_id bigint primary key,app_candidate_id bigint,app_position_id bigint,app_created_at timestamp)",
            "create table t_sch_appointment(apt_id bigint primary key,apt_candidate_id bigint,apt_position_id bigint,apt_start_time timestamp,apt_status int,apt_updated_at timestamp)",
            "create table t_int_session(ses_id bigint primary key,ses_candidate_id bigint,ses_position_id bigint)",
            "create table t_int_evaluation(evl_id bigint primary key,evl_session_id bigint,evl_created_at timestamp)",
            "create table t_msg(msg_id bigint auto_increment primary key,msg_receiver_id bigint,msg_sender_id bigint,msg_type int,msg_title varchar(255),msg_content varchar(4000),msg_is_read int,msg_target_url varchar(500),msg_created_at timestamp default current_timestamp)",
            "insert into sys_user values(9,'合成招聘者','0','0'),(10,'合成同企业招聘者','0','0'),(19,'合成其他企业','0','0'),(101,'合成求职者','0','0'),(99,'合成停用','1','0')",
            "insert into t_cmp_binding values(1,9,1),(1,10,1),(2,19,1),(1,99,1)",
            "insert into t_pos values(7,'合成岗位',1),(8,'另一企业岗位',2)",
            "insert into t_tal values(11,101)")) jdbc.execute(sql);
        var factory=new SqlSessionFactoryBean();factory.setDataSource(ds);
        factory.setMapperLocations(new ClassPathResource("mapper/enterprise/EnterpriseSystemNoticeMapper.xml"));
        mapper=new SqlSessionTemplate(factory.getObject()).getMapper(EnterpriseSystemNoticeMapper.class);
        companies=mock(DashboardMapper.class);
        when(companies.selectCompanyIdByUser(9L)).thenReturn(1L);
        when(companies.selectCompanyIdByUser(10L)).thenReturn(1L);
        when(companies.selectCompanyIdByUser(19L)).thenReturn(2L);
        var target=new EnterpriseSystemNoticeService();
        ReflectionTestUtils.setField(target,"mapper",mapper);ReflectionTestUtils.setField(target,"companies",companies);
        var proxy=new ProxyFactory(target);proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(ds),new AnnotationTransactionAttributeSource()));
        service=(EnterpriseSystemNoticeService)proxy.getProxy();now=LocalDateTime.now(ZoneOffset.ofHours(8));
    }
    private void events() {
        jdbc.update("insert into t_app_record values(31,11,7,?)",now.minusMinutes(20));
        jdbc.update("insert into t_sch_appointment values(41,11,7,?,0,?)",now.plusMinutes(30),now);
        jdbc.execute("insert into t_int_session values(51,11,7)");
        jdbc.update("insert into t_int_evaluation values(61,51,?)",now.minusMinutes(10));
    }
    private int count() {return jdbc.queryForObject("select count(*) from t_msg",Integer.class);}
    @Test void realBusinessEventsCreateReadOnlyUnreadNoticesWithoutImMessages() {
        events();service.refresh(9L);
        assertEquals(3,count());
        assertEquals(List.of("收到新的简历投递","面试即将开始","面试报告已生成"),jdbc.queryForList("select msg_title from t_msg order by msg_id",String.class));
        assertTrue(jdbc.queryForList("select msg_content from t_msg",String.class).stream().allMatch(s->s.contains("合成岗位")&&s.contains("合成求职者")));
        assertEquals(3,jdbc.queryForObject("select count(*) from t_msg where msg_is_read=0 and msg_receiver_id=9 and msg_sender_id=0",Integer.class));
    }
    @Test void repeatedRefreshAndReadDoNotDuplicateNotices() {
        events();service.refresh(9L);jdbc.update("update t_msg set msg_is_read=1");service.refresh(9L);
        assertEquals(3,count());assertEquals(0,jdbc.queryForObject("select sum(msg_is_read=0) from t_msg",Integer.class));
    }
    @Test void otherCompanyAndUnboundOrInactiveAccountsCannotReceiveTheseEvents() {
        events();service.refresh(19L);service.refresh(101L);service.refresh(99L);
        assertEquals(0,count());
        service.refresh(9L);service.refresh(10L);
        assertEquals(6,count());assertEquals(0,jdbc.queryForObject("select count(*) from t_msg where msg_receiver_id=19",Integer.class));
    }
    @Test void futureWindowExpiredCancelledAndOldEventsAreNotFaked() {
        jdbc.update("insert into t_sch_appointment values(41,11,7,?,0,?)",now.minusMinutes(1),now.minusDays(8));
        jdbc.update("insert into t_sch_appointment values(42,11,7,?,0,?)",now.plusMinutes(61),now);
        jdbc.update("insert into t_sch_appointment values(43,11,7,?,2,?)",now.plusMinutes(30),now.minusDays(8));
        jdbc.update("insert into t_app_record values(31,11,7,?)",now.minusDays(8));
        service.refresh(9L);assertEquals(0,count());
    }
    @Test void changedAppointmentTimeGetsOneReminderForNewSlot() {
        events();service.refresh(9L);jdbc.update("update t_sch_appointment set apt_start_time=? where apt_id=41",now.plusMinutes(45));
        service.refresh(9L);service.refresh(9L);
        assertEquals(4,count());assertEquals(2,jdbc.queryForObject("select count(*) from t_msg where msg_title='面试即将开始'",Integer.class));
    }
    @Test void confirmedAndCancelledStateNoticesDoNotChangeAppointment() {
        jdbc.update("insert into t_sch_appointment values(41,11,7,?,1,?)",now.plusDays(1),now);
        service.refresh(9L);assertEquals("面试安排已确认",jdbc.queryForObject("select msg_title from t_msg",String.class));
        jdbc.update("update t_sch_appointment set apt_status=2 where apt_id=41");service.refresh(9L);service.refresh(9L);
        assertEquals(2,count());assertEquals(2,jdbc.queryForObject("select apt_status from t_sch_appointment",Integer.class));
    }
    @Test void concurrentSchedulerAndPageRefreshCreateOnlyOneNoticePerEvent() throws Exception {
        events();var pool=Executors.newFixedThreadPool(2);
        try {Callable<Void> action=()->{service.refresh(9L);return null;};for(var result:pool.invokeAll(List.of(action,action)))result.get();}
        finally {pool.shutdownNow();}assertEquals(3,count());
    }
    @Test void failedNoticeWriteRollsBackWholeBatch() {
        events();jdbc.execute("alter table t_msg add constraint reject_reports check(msg_type<>2)");
        assertThrows(RuntimeException.class,()->service.refresh(9L));assertEquals(0,count());
        assertEquals(1,jdbc.queryForObject("select count(*) from t_app_record",Integer.class));
    }
    @Test void notificationBatchesContinuePastFiftyWithoutDroppingEvents() {
        for(int i=1;i<=55;i++)jdbc.update("insert into t_app_record values(?,11,7,?)",i,now.minusMinutes(1));
        service.refresh(9L);assertEquals(50,count());service.refresh(9L);assertEquals(55,count());service.refresh(9L);assertEquals(55,count());
        assertEquals(List.of(9L,10L,19L),mapper.recipients(0L));
        assertEquals(List.of(19L),mapper.recipients(10L));
    }

    private EnterpriseNoticeDestinationService destinations() {
        var target=new EnterpriseNoticeDestinationService();
        ReflectionTestUtils.setField(target,"mapper",mapper);
        ReflectionTestUtils.setField(target,"companies",companies);
        return target;
    }
    private Long noticeId(String kind) {
        return jdbc.queryForObject("select msg_id from t_msg where msg_receiver_id=9 and msg_target_url like ?",Long.class,"/enterprise/system-events/"+kind+"/%");
    }
    @Test void applicationLinkResolvesExactCandidateAndJobOnlyForNoticeRecipientAndCurrentCompany() {
        events();service.refresh(9L);Long id=noticeId("applications");
        var result=destinations().resolve(9L,id);
        assertEquals("candidate",result.get("kind"));assertEquals(11L,((Number)result.get("candidateId")).longValue());
        assertEquals(7L,((Number)result.get("positionId")).longValue());assertEquals(31L,((Number)result.get("applicationId")).longValue());
        assertThrows(com.ruoyi.common.exception.ServiceException.class,()->destinations().resolve(10L,id));
        assertThrows(com.ruoyi.common.exception.ServiceException.class,()->destinations().resolve(19L,id));
        when(companies.selectCompanyIdByUser(9L)).thenReturn(2L);
        assertThrows(com.ruoyi.common.exception.ServiceException.class,()->destinations().resolve(9L,id));
    }
    @Test void notificationLinksRejectExternalMalformedAndDeletedRecords() {
        events();service.refresh(9L);Long id=noticeId("applications");
        for(String target:List.of("https://other.invalid/enterprise/system-events/applications/31",
            "/enterprise/system-events/applications/31?companyId=1","/enterprise/system-events/applications/31/status/1",
            "/enterprise/system-events/interviews/41","/enterprise/system-events/reports/999999999999999999999999999999")) {
            jdbc.update("update t_msg set msg_target_url=? where msg_id=?",target,id);
            assertThrows(com.ruoyi.common.exception.ServiceException.class,()->destinations().resolve(9L,id));
        }
        jdbc.update("update t_msg set msg_target_url='/enterprise/system-events/applications/31' where msg_id=?",id);
        jdbc.update("delete from t_app_record where app_id=31");
        assertThrows(com.ruoyi.common.exception.ServiceException.class,()->destinations().resolve(9L,id));
        assertThrows(com.ruoyi.common.exception.ServiceException.class,()->destinations().resolve(9L,0L));
    }
    @Test void interviewLinkResolvesLatestScheduleAndReportLinkResolvesRealScopedReport() {
        events();service.refresh(9L);
        jdbc.execute("alter table t_sch_appointment add apt_end_time timestamp");
        jdbc.execute("alter table t_sch_appointment add apt_interviewer_id bigint default 9");
        jdbc.update("update t_sch_appointment set apt_start_time=?,apt_end_time=? where apt_id=41",now.plusMinutes(45),now.plusMinutes(90));
        var interview=destinations().resolve(9L,noticeId("interviews"));
        assertEquals("interview",interview.get("kind"));assertEquals(41L,((Number)interview.get("appointmentId")).longValue());
        assertEquals(now.plusMinutes(45).format(DateTimeFormatter.ofPattern("yyyyMMddHHmm")),String.valueOf(interview.get("startTime")));
        jdbc.execute("alter table t_int_session add ses_appointment_id bigint default 41");
        jdbc.execute("alter table t_int_session add ses_start_at timestamp");
        for(String col:List.of("evl_summary","evl_advantages","evl_risks","evl_gaps","evl_dimension_scores"))
            jdbc.execute("alter table t_int_evaluation add "+col+" varchar(1000)");
        jdbc.execute("alter table t_int_evaluation add evl_overall_score decimal(5,2) default 86");
        jdbc.execute("alter table t_int_evaluation add evl_recommendation int default 1");
        jdbc.update("update t_int_evaluation set evl_summary='合成面试总结',evl_dimension_scores='{\"技术\":86}'");
        var report=destinations().resolve(9L,noticeId("reports"));
        assertEquals("report",report.get("kind"));assertEquals(51L,((Number)report.get("sessionId")).longValue());
        assertEquals("合成面试总结",report.get("summary"));
        when(companies.selectCompanyIdByUser(9L)).thenReturn(2L);
        assertThrows(com.ruoyi.common.exception.ServiceException.class,()->destinations().resolve(9L,noticeId("reports")));
    }
}
