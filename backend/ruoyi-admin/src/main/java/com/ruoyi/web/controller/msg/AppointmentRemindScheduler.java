package com.ruoyi.web.controller.msg;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import com.ruoyi.system.service.EmailService;

/**
 * 面试前邮件提醒定时任务。
 *
 * <p>每分钟扫描「待面试（apt_status 0/1）」预约，对开始前配置窗口内的场次，
 * 复用全局 SMTP（EmailService）给候选人发提醒邮件。</p>
 *
 * <p>提醒状态机（t_sch_appointment.apt_notified，迁移脚本
 * backend/doc/migrate_appointment_notify_20261022.sql）：
 * 0 未处理（默认，可被认领）、2 发送中（已被某实例认领）、1 已处理
 * （邮件已发送，或按策略跳过，如缺邮箱——1 表示本次提醒已处理，不代表发送成功）。</p>
 *
 * <p>防重与失败恢复：认领用条件更新（0→2），多实例并发下仅一个实例发送；
 * 发送成功置 1；SMTP 失败保留 2，由每轮开头的回收把超过退避时间
 * （ruoyi.msg.interview-remind-retry-minutes，默认 30 分钟）仍停留在 2 的预约
 * 重置为 0，实现受控重试，避免每分钟无限重试，也不静默丢失提醒。
 * 进程崩溃与「发送成功但标记失败」同样经回收恢复（可能造成一次重复提醒，
 * 属数据库不可用窗口内的残余风险，见交付说明）。</p>
 *
 * <p>提醒窗口分钟数由 ruoyi.msg.interview-remind-window-minutes 控制，默认 60；
 * 时间统一按 UTC+8 计算，与面试调度模块口径一致。</p>
 */
@Component
public class AppointmentRemindScheduler {

    /** 发送成功后的标记重试次数（数据库瞬时故障时避免把已发送的场次留成待处理） */
    private static final int MARK_RETRIES = 3;

    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Value("${ruoyi.msg.interview-remind-window-minutes:60}")
    private long windowMinutes;

    @Value("${ruoyi.msg.interview-remind-retry-minutes:30}")
    private long retryMinutes;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private EmailService emailService;

    @Scheduled(fixedDelay = 60_000L)
    public void remindUpcomingInterviews() {
        LocalDateTime now = LocalDateTime.now(ZoneOffset.ofHours(8));
        // 1. 回收超时认领：崩溃残留与 SMTP 失败后的受控重试退避（仅有效预约）
        jdbcTemplate.update(
            "UPDATE t_sch_appointment SET apt_notified = 0 " +
            "WHERE apt_notified = 2 AND apt_status IN (0, 1) AND apt_updated_at <= ?",
            TIME.format(now.minusMinutes(retryMinutes)));
        // 2. 扫描窗口内待处理预约（已取消/已完成由状态过滤排除；已开始的不再提醒）
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT a.apt_id AS aptId, a.apt_start_time AS startTime, a.apt_meeting_url AS meetingUrl, " +
            "p.pos_title AS positionTitle, u.user_id AS userId, u.nick_name AS nickName, u.email AS email " +
            "FROM t_sch_appointment a " +
            "LEFT JOIN t_tal t ON a.apt_candidate_id = t.tal_id " +
            "LEFT JOIN sys_user u ON t.tal_user_id = u.user_id " +
            "LEFT JOIN t_pos p ON a.apt_position_id = p.pos_id " +
            "WHERE a.apt_status IN (0, 1) AND a.apt_notified = 0 " +
            "AND a.apt_start_time >= ? " +
            "AND a.apt_start_time <= ?",
            TIME.format(now), TIME.format(now.plusMinutes(windowMinutes)));

        for (Map<String, Object> row : rows) {
            Long aptId = ((Number) row.get("aptId")).longValue();
            // 认领：条件更新保证多实例并发下只有一个实例执行发送
            int claimed = jdbcTemplate.update(
                "UPDATE t_sch_appointment SET apt_notified = 2, apt_updated_at = NOW() " +
                "WHERE apt_id = ? AND apt_notified = 0", aptId);
            if (claimed != 1) {
                continue;
            }
            String email = row.get("email") == null ? null : String.valueOf(row.get("email")).trim();
            if (email == null || email.isEmpty()) {
                // 缺邮箱只处理一次：写失败台账并置已处理，不生成虚假的发送成功记录
                writeRecord(row, "email", "1", "缺少候选人邮箱，未发送");
                jdbcTemplate.update(
                    "UPDATE t_sch_appointment SET apt_notified = 1 WHERE apt_id = ? AND apt_notified = 2", aptId);
                continue;
            }
            String name = row.get("nickName") == null ? "候选人" : String.valueOf(row.get("nickName"));
            String position = row.get("positionTitle") == null ? "" : String.valueOf(row.get("positionTitle"));
            String startTime = row.get("startTime") == null ? "" : String.valueOf(row.get("startTime"));
            String meetingUrl = row.get("meetingUrl") == null ? "" : String.valueOf(row.get("meetingUrl"));
            String subject = "面试提醒 - " + position;
            String content = name + "您好：您预约的岗位「" + position + "」面试将于 " + startTime
                    + " 开始，请准时参加。会议链接：" + meetingUrl;

            boolean ok = emailService.sendSimpleMail(email, subject, content);
            if (ok) {
                if (markDone(aptId)) {
                    writeRecord(row, "email", "0", null);
                } else {
                    // 邮件已发送但标记写不回去：记入台账便于排查，残留 2 由回收恢复（可能重复提醒）
                    writeRecord(row, "email", "1", "邮件已发送但提醒标记写入失败，可能重复提醒");
                }
            } else {
                // SMTP 失败：保留发送中状态，由回收在退避时间后重置为待处理，受控重试
                writeRecord(row, "email", "1", "邮件投递失败（SMTP认证或网络异常）");
            }
        }
    }

    /** 发送成功置已处理；数据库瞬时故障时短暂重试，避免已发送场次被回收后重复提醒。 */
    private boolean markDone(Long aptId) {
        for (int attempt = 0; attempt < MARK_RETRIES; attempt++) {
            try {
                if (jdbcTemplate.update(
                        "UPDATE t_sch_appointment SET apt_notified = 1 WHERE apt_id = ? AND apt_notified = 2", aptId) == 1) {
                    return true;
                }
            } catch (RuntimeException ignored) {
                // 瞬时故障，继续重试
            }
            try {
                Thread.sleep(200L);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        return false;
    }

    /** 写发送台账 t_msg_record */
    private void writeRecord(Map<String, Object> row, String channel, String status, String failReason) {
        jdbcTemplate.update(
            "INSERT INTO t_msg_record (mr_user_name, mr_contact, mr_channel, mr_content, mr_status, mr_fail_reason) " +
            "VALUES (?, ?, ?, ?, ?, ?)",
            row.get("nickName"), row.get("email"), channel,
            "面试提醒：" + row.get("positionTitle") + " @ " + row.get("startTime"),
            status, failReason);
    }
}
