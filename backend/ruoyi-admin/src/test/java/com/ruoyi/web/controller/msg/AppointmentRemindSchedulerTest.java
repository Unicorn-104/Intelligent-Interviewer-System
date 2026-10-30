package com.ruoyi.web.controller.msg;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.system.service.EmailService;

/**
 * 面试前邮件提醒定时任务：
 * 窗口过滤、认领制防重（多实例并发仅一个发送）、缺邮箱只处理一次、
 * SMTP 失败受控重试（退避回收）、崩溃残留与「发送成功但标记失败」的恢复。
 */
public class AppointmentRemindSchedulerTest
{
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private JdbcTemplate jdbc;
    private EmailService emailService;
    private AppointmentRemindScheduler scheduler;

    @BeforeEach
    void setup()
    {
        var ds = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=5000", "sa", "");
        jdbc = new JdbcTemplate(ds);
        for (String sql : List.of(
            "create table t_sch_appointment(apt_id bigint auto_increment primary key, apt_candidate_id bigint, apt_position_id bigint, apt_start_time timestamp, apt_end_time timestamp, apt_status int, apt_notified int default 0, apt_updated_at timestamp, apt_meeting_url varchar(255))",
            "create table t_tal(tal_id bigint primary key, tal_user_id bigint)",
            "create table sys_user(user_id bigint primary key, nick_name varchar(100), email varchar(100))",
            "create table t_pos(pos_id bigint primary key, pos_title varchar(100))",
            "create table t_msg_record(mr_id bigint auto_increment primary key, mr_user_name varchar(100), mr_contact varchar(100), mr_channel varchar(50), mr_content varchar(1000), mr_status char(1), mr_fail_reason varchar(500))",
            "insert into t_tal values(11,101),(12,102)",
            "insert into sys_user values(101,'候选人甲','a@example.com'),(102,'候选人乙',null)",
            "insert into t_pos values(7,'合成岗位')")) jdbc.execute(sql);
        emailService = mock(EmailService.class);
        scheduler = new AppointmentRemindScheduler();
        ReflectionTestUtils.setField(scheduler, "jdbcTemplate", jdbc);
        ReflectionTestUtils.setField(scheduler, "emailService", emailService);
        ReflectionTestUtils.setField(scheduler, "windowMinutes", 60L);
        ReflectionTestUtils.setField(scheduler, "retryMinutes", 30L);
    }

    /** candidateId 11 有邮箱，12 无邮箱（邮箱来自 sys_user 关联，不在预约表上）。 */
    private long appointment(int candidateId, int status, int notified, int startOffsetMin)
    {
        LocalDateTime now = LocalDateTime.now(ZoneOffset.ofHours(8));
        String start = TIME.format(now.plusMinutes(startOffsetMin));
        String end = TIME.format(now.plusMinutes(startOffsetMin + 45));
        jdbc.update("insert into t_sch_appointment(apt_candidate_id,apt_position_id,apt_start_time,apt_end_time,"
                + "apt_status,apt_notified,apt_updated_at,apt_meeting_url) values(?,?,?,?,?,?,?,?)",
                candidateId, 7, start, end, status, notified, TIME.format(now), "https://meeting.example.com/1");
        return jdbc.queryForObject("select max(apt_id) from t_sch_appointment", Long.class);
    }
    private int notified(long aptId)
    {
        return jdbc.queryForObject("select apt_notified from t_sch_appointment where apt_id=" + aptId, Integer.class);
    }
    private int records() { return jdbc.queryForObject("select count(*) from t_msg_record", Integer.class); }
    private int failedRecords() { return jdbc.queryForObject("select count(*) from t_msg_record where mr_status='1'", Integer.class); }

    // ============ 普通提醒与重复调度 ============

    @Test
    void sendsWithinWindowAndMarksDone()
    {
        long id = appointment(11, 0, 0, 30);
        when(emailService.sendSimpleMail(anyString(), anyString(), anyString())).thenReturn(true);
        scheduler.remindUpcomingInterviews();
        verify(emailService).sendSimpleMail(eq("a@example.com"), contains("合成岗位"), anyString());
        assertEquals(1, notified(id));
        assertEquals(1, records());
        assertEquals(0, failedRecords());
    }

    @Test
    void repeatRunDoesNotResendOrAddRecords()
    {
        long id = appointment(11, 0, 0, 30);
        when(emailService.sendSimpleMail(anyString(), anyString(), anyString())).thenReturn(true);
        scheduler.remindUpcomingInterviews();
        scheduler.remindUpcomingInterviews();
        verify(emailService, times(1)).sendSimpleMail(anyString(), anyString(), anyString());
        assertEquals(1, notified(id));
        assertEquals(1, records());
    }

    // ============ 状态与时间过滤 ============

    @Test
    void cancelledAndCompletedAppointmentsAreNeverReminded()
    {
        appointment(11, 2, 0, 30);
        appointment(11, 3, 0, 30);
        scheduler.remindUpcomingInterviews();
        verify(emailService, never()).sendSimpleMail(anyString(), anyString(), anyString());
        assertEquals(0, records());
    }

    @Test
    void startedAndFarFutureAppointmentsAreNotReminded()
    {
        appointment(11, 0, 0, -10);
        appointment(11, 0, 0, 90);
        scheduler.remindUpcomingInterviews();
        verify(emailService, never()).sendSimpleMail(anyString(), anyString(), anyString());
        assertEquals(0, records());
    }

    // ============ 缺邮箱：只处理一次 ============

    @Test
    void missingEmailProcessedOnceWithFailureLedgerAndNoFakeSuccess()
    {
        long id = appointment(12, 0, 0, 30);
        scheduler.remindUpcomingInterviews();
        assertEquals(1, notified(id));
        assertEquals(1, records());
        assertEquals(1, failedRecords());
        assertEquals("缺少候选人邮箱，未发送",
                jdbc.queryForObject("select mr_fail_reason from t_msg_record", String.class));
        scheduler.remindUpcomingInterviews();
        assertEquals(1, records());
        verify(emailService, never()).sendSimpleMail(anyString(), anyString(), anyString());
    }

    // ============ SMTP 失败：受控重试 ============

    @Test
    void smtpFailureKeepsClaimAndRetriesOnlyAfterBackoff()
    {
        long id = appointment(11, 0, 0, 30);
        AtomicInteger calls = new AtomicInteger();
        when(emailService.sendSimpleMail(anyString(), anyString(), anyString())).thenAnswer(inv -> {
            return calls.incrementAndGet() > 1;
        });
        scheduler.remindUpcomingInterviews();
        assertEquals(2, notified(id));
        assertEquals(1, failedRecords());
        // 退避时间内不重试
        scheduler.remindUpcomingInterviews();
        assertEquals(1, calls.get());
        // 超过退避时间：回收认领后重试，第二次成功
        jdbc.update("update t_sch_appointment set apt_updated_at=? where apt_id=" + id,
                TIME.format(LocalDateTime.now(ZoneOffset.ofHours(8)).minusMinutes(31)));
        scheduler.remindUpcomingInterviews();
        assertEquals(2, calls.get());
        assertEquals(1, notified(id));
        assertEquals(2, records());
    }

    // ============ 并发与异常恢复 ============

    @Test
    void concurrentRunsOnlyOneInstanceSends() throws Exception
    {
        long id = appointment(11, 0, 0, 30);
        when(emailService.sendSimpleMail(anyString(), anyString(), anyString())).thenAnswer(inv -> {
            Thread.sleep(300);
            return true;
        });
        var executor = Executors.newFixedThreadPool(2);
        try {
            var results = executor.invokeAll(List.of(
                    (Callable<Boolean>) () -> { scheduler.remindUpcomingInterviews(); return true; },
                    (Callable<Boolean>) () -> { scheduler.remindUpcomingInterviews(); return true; }));
            assertTrue(results.stream().allMatch(f -> { try { return f.get(); } catch (Exception e) { return false; } }));
        } finally { executor.shutdownNow(); }
        verify(emailService, times(1)).sendSimpleMail(anyString(), anyString(), anyString());
        assertEquals(1, notified(id));
        assertEquals(1, records());
    }

    @Test
    void staleClaimIsRecoveredAndReprocessed()
    {
        // 模拟进程崩溃残留或「邮件已发送但标记写回失败」：发送中(2)且超过退避时间
        long id = appointment(11, 0, 2, 30);
        jdbc.update("update t_sch_appointment set apt_updated_at=? where apt_id=" + id,
                TIME.format(LocalDateTime.now(ZoneOffset.ofHours(8)).minusMinutes(40)));
        when(emailService.sendSimpleMail(anyString(), anyString(), anyString())).thenReturn(true);
        scheduler.remindUpcomingInterviews();
        assertEquals(1, notified(id));
        verify(emailService, times(1)).sendSimpleMail(anyString(), anyString(), anyString());
    }

    @Test
    void recoveryLeavesCancelledClaimsAlone()
    {
        long id = appointment(11, 2, 2, 30);
        jdbc.update("update t_sch_appointment set apt_updated_at=? where apt_id=" + id,
                TIME.format(LocalDateTime.now(ZoneOffset.ofHours(8)).minusMinutes(40)));
        scheduler.remindUpcomingInterviews();
        assertEquals(2, notified(id));
        verify(emailService, never()).sendSimpleMail(anyString(), anyString(), anyString());
    }
}
