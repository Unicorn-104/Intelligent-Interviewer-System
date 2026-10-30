package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.sql.Timestamp;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
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
import com.ruoyi.enterprise.mapper.InterviewerSlotMapper;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;

/**
 * 面试官可用时段整周覆盖保存：
 * 只删除未被有效预约引用的时段；与待确认/已确认面试冲突时整笔拒绝；
 * 通过面试官行锁与预约创建/改期串行化。
 */
public class InterviewerSlotServiceTest
{
    private JdbcTemplate jdbc;
    private InterviewerSlotServiceImpl slots;
    private InterviewScheduleMapper scheduleMapper;
    private InterviewScheduleServiceImpl schedule;

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
        jdbc.execute("CREATE ALIAS date_format FOR 'com.ruoyi.enterprise.service.impl.InterviewerSlotServiceTest.dateFormat'");
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
            "insert into sys_user values(19,'0','面试官'),(20,'0','面试官二'),(11,'0','候选人')",
            "insert into t_tal(tal_id,tal_user_id) values(11,11)",
            "insert into t_pos values(7,1,'合成岗位',1)",
            "insert into t_process_instance values(11,7,0)",
            "insert into t_cmp_binding values(1,19,1),(1,20,1)",
            "insert into t_app_record(app_candidate_id,app_position_id,app_status) values(11,7,1)",
            "insert into t_process_stage values(31,1,'技术面试',2,1,'{\"duration\":60}')")) jdbc.execute(sql);
        var factory = new SqlSessionFactoryBean();
        factory.setDataSource(ds);
        factory.setMapperLocations(new ClassPathResource("mapper/enterprise/InterviewerSlotMapper.xml"),
                new ClassPathResource("mapper/enterprise/InterviewScheduleMapper.xml"));
        var template = new SqlSessionTemplate(factory.getObject());
        var slotMapper = template.getMapper(InterviewerSlotMapper.class);
        scheduleMapper = template.getMapper(InterviewScheduleMapper.class);
        var target = new InterviewerSlotServiceImpl();
        ReflectionTestUtils.setField(target, "slotMapper", slotMapper);
        var proxy = new ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(ds),
                new AnnotationTransactionAttributeSource()));
        slots = (InterviewerSlotServiceImpl) proxy.getProxy();
        var scheduleTarget = new InterviewScheduleServiceImpl();
        var companyMapper = mock(DashboardMapper.class);
        when(companyMapper.selectCompanyIdByUser(1L)).thenReturn(1L);
        var jobs = mock(EnterpriseJobMapper.class);
        when(jobs.selectJobById(7L,1L)).thenReturn(Map.of("posId",7L));
        ReflectionTestUtils.setField(scheduleTarget, "scheduleMapper", scheduleMapper);
        ReflectionTestUtils.setField(scheduleTarget, "dashboardMapper", companyMapper);
        ReflectionTestUtils.setField(scheduleTarget, "jobMapper", jobs);
        ReflectionTestUtils.setField(scheduleTarget, "screeningMapper", mock(com.ruoyi.enterprise.mapper.ScreeningMapper.class));
        var scheduleProxy = new ProxyFactory(scheduleTarget);
        scheduleProxy.setProxyTargetClass(true);
        scheduleProxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(ds),
                new AnnotationTransactionAttributeSource()));
        schedule = (InterviewScheduleServiceImpl) scheduleProxy.getProxy();
    }

    private Map<String, Object> slot(String start, String end)
    {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("startTime", start);
        row.put("endTime", end);
        return row;
    }
    private Map<String, Object> save(List<Map<String, Object>> slots)
    {
        return slotsService().saveSlots(19L, "2099-01-02", slots);
    }
    private InterviewerSlotServiceImpl slotsService() { return slots; }
    private int slotCount() { return jdbc.queryForObject("select count(*) from t_sch_slot", Integer.class); }
    private int freeCount() { return jdbc.queryForObject("select count(*) from t_sch_slot where slt_status=1", Integer.class); }

    /** 邀约占用面试官19的时段（真实 Mapper，占用状态 0）。 */
    private long inviteBooking(String start, int duration)
    {
        var result = schedule.invite(1L, 11L, 7L, 31L, 19L, start, duration);
        return ((Number) result.get("appointmentId")).longValue();
    }

    // ============ 基础保存 ============

    @Test
    void savesWeekWithoutAppointmentsReplacingPreviousFreeSlots()
    {
        save(List.of(slot("2099-01-02 09:00:00", "2099-01-02 10:00:00")));
        save(List.of(slot("2099-01-02 10:00:00", "2099-01-02 11:00:00")));
        assertEquals(1, slotCount());
        assertEquals("2099-01-02 10:00", jdbc.queryForObject(
                "select date_format(slt_start_time,'%Y-%m-%d %H:%i') from t_sch_slot", String.class));
        assertEquals(1, freeCount());
    }

    @Test
    void deletesUnoccupiedSlotWhenOmitted()
    {
        save(List.of(slot("2099-01-02 09:00:00", "2099-01-02 10:00:00"),
                slot("2099-01-02 14:00:00", "2099-01-02 15:00:00")));
        save(List.of(slot("2099-01-02 09:00:00", "2099-01-02 10:00:00")));
        assertEquals(1, slotCount());
        assertEquals(0, jdbc.queryForObject("select count(*) from t_sch_slot where slt_status=0", Integer.class));
    }

    @Test
    void modifiesUnoccupiedSlotTime()
    {
        save(List.of(slot("2099-01-02 09:00:00", "2099-01-02 10:00:00")));
        save(List.of(slot("2099-01-02 09:30:00", "2099-01-02 10:30:00")));
        assertEquals(1, slotCount());
        assertEquals("2099-01-02 09:30", jdbc.queryForObject(
                "select date_format(slt_start_time,'%Y-%m-%d %H:%i') from t_sch_slot", String.class));
    }

    // ============ 已预约时段保护 ============

    @Test
    void savesWeekContainingBookedSlotsKeepsBookedSlotAndItsLink()
    {
        save(List.of(slot("2099-01-02 09:00:00", "2099-01-02 10:00:00")));
        long appointmentId = inviteBooking("2099-01-02 09:00", 60);
        long bookedSlot = jdbc.queryForObject("select apt_slot_id from t_sch_appointment where apt_id=" + appointmentId, Long.class);
        // 整周重存：已预约时段保留，自由时段被替换
        save(List.of(slot("2099-01-02 14:00:00", "2099-01-02 15:00:00")));
        assertEquals(2, slotCount());
        assertEquals(0, jdbc.queryForObject("select slt_status from t_sch_slot where slt_id=" + bookedSlot, Integer.class));
        assertEquals(bookedSlot, jdbc.queryForObject("select apt_slot_id from t_sch_appointment where apt_id=" + appointmentId, Long.class));
        assertEquals(1, freeCount());
    }

    @Test
    void keepsBookedSlotEvenWhenStatusColumnSaysOccupied()
    {
        // 直接构造：状态0但无有效预约引用的时段可删；有有效预约引用的必须保留（不只看状态值）
        save(List.of(slot("2099-01-02 09:00:00", "2099-01-02 10:00:00")));
        long appointmentId = inviteBooking("2099-01-02 09:00", 60);
        long bookedSlot = jdbc.queryForObject("select apt_slot_id from t_sch_appointment where apt_id=" + appointmentId, Long.class);
        jdbc.update("insert into t_sch_slot(slt_interviewer_id,slt_start_time,slt_end_time,slt_status) values(19,'2099-01-02 15:00','2099-01-02 16:00',0)");
        save(List.of(slot("2099-01-02 14:00:00", "2099-01-02 15:00:00")));
        // 保留：已预约时段；删除：未被引用的遗留占用时段
        assertEquals(2, slotCount());
        assertEquals(bookedSlot, jdbc.queryForObject("select apt_slot_id from t_sch_appointment where apt_id=" + appointmentId, Long.class));
    }

    // ============ 冲突拒绝 ============

    @Test
    void rejectsAvailabilityOverlappingConfirmedInterview()
    {
        long appointmentId = inviteBooking("2099-01-02 09:00", 60);
        jdbc.update("update t_sch_appointment set apt_status=1 where apt_id=" + appointmentId);
        ServiceException error = assertThrows(ServiceException.class,
                () -> save(List.of(slot("2099-01-02 08:30:00", "2099-01-02 09:30:00"))));
        assertTrue(error.getMessage().contains("冲突"));
        assertEquals(1, jdbc.queryForObject("select apt_status from t_sch_appointment where apt_id=" + appointmentId, Integer.class));
        assertEquals(0, freeCount());
    }

    @Test
    void rejectsAvailabilityOverlappingPendingInterviewAndKeepsAppointment()
    {
        inviteBooking("2099-01-02 09:00", 60);
        assertThrows(ServiceException.class,
                () -> save(List.of(slot("2099-01-02 09:30:00", "2099-01-02 10:30:00"))));
        assertEquals(0, freeCount());
        assertEquals(1, jdbc.queryForObject("select count(*) from t_sch_appointment where apt_status=0", Integer.class));
    }

    @Test
    void touchingBoundaryAvailabilityIsAllowed()
    {
        inviteBooking("2099-01-02 09:00", 60);
        save(List.of(slot("2099-01-02 10:00:00", "2099-01-02 11:00:00")));
        assertEquals(1, freeCount());
    }

    // ============ 取消/改期后的周历更新 ============

    @Test
    void saveAfterCancelRemovesReleasedSlot()
    {
        long appointmentId = inviteBooking("2099-01-02 09:00", 60);
        jdbc.update("insert into t_tal_status_log(tsl_candidate_id,tsl_from_status,tsl_to_status) values(11,1,2)");
        schedule.updateStatus(1L, appointmentId, 2);
        // 取消后时段已释放(1)且预约不再有效：周历重存时该时段可被删除
        assertEquals(1, jdbc.queryForObject("select slt_status from t_sch_slot", Integer.class));
        save(List.of(slot("2099-01-02 14:00:00", "2099-01-02 15:00:00")));
        assertEquals(1, slotCount());
        assertEquals(1, freeCount());
    }

    @Test
    void saveAfterRescheduleKeepsNewBookedSlotAndRemovesOldReleasedSlot()
    {
        long appointmentId = inviteBooking("2099-01-02 09:00", 60);
        var moved = schedule.reschedule(1L, appointmentId, "2099-01-02 15:00", null, null);
        long newSlot = ((Number) moved.get("newSlotId")).longValue();
        // 改期后：新时段占用(0)且有有效预约引用 → 保留；旧时段已释放 → 删除
        save(List.of(slot("2099-01-02 14:00:00", "2099-01-02 15:00:00")));
        assertEquals(2, slotCount());
        assertEquals(0, jdbc.queryForObject("select slt_status from t_sch_slot where slt_id=" + newSlot, Integer.class));
        assertEquals(newSlot, jdbc.queryForObject("select apt_slot_id from t_sch_appointment where apt_id=" + appointmentId, Long.class));
    }

    // ============ 并发保存与邀约 ============

    @Test
    void concurrentSaveAndInviteNeverLoseBookedSlot() throws Exception
    {
        var executor = Executors.newFixedThreadPool(2);
        try {
            Callable<Boolean> saver = () -> {
                try { save(List.of(slot("2099-01-02 09:00:00", "2099-01-02 09:45:00"))); return true; }
                catch (ServiceException e) { return false; }
            };
            Callable<Boolean> inviter = () -> {
                try { inviteBooking("2099-01-02 10:00", 60); return true; }
                catch (ServiceException e) { return false; }
            };
            var results = executor.invokeAll(List.of(saver, inviter));
            assertTrue(results.stream().allMatch(f -> { try { return f.get(); } catch (Exception e) { return false; } }));
            // 无论先后：预约的时段必须存在且关联完好，不被周历保存删除
            assertEquals(1, jdbc.queryForObject("select count(*) from t_sch_appointment", Integer.class));
            assertEquals(1, jdbc.queryForObject("select count(*) from t_sch_appointment where apt_slot_id is not null", Integer.class));
            assertEquals(1, jdbc.queryForObject("""
                    select count(*) from t_sch_appointment a
                    join t_sch_slot s on s.slt_id = a.apt_slot_id
                    where a.apt_status in (0,1) and s.slt_status = 0""", Integer.class));
        } finally { executor.shutdownNow(); }
    }
}
