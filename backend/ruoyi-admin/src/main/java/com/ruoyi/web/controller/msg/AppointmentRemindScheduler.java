package com.ruoyi.web.controller.msg;

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
 * <p>每分钟扫描「待面试（apt_status 0/1）且未提醒」的预约，对开始前配置窗口内的场次，
 * 复用全局 SMTP（EmailService）给候选人发提醒邮件；成功后置已提醒标记并写发送台账，
 * 失败保留未标记由下一轮重试。只读扫描业务表，不修改企业端写逻辑。</p>
 *
 * <p>提醒窗口分钟数由配置项 ruoyi.msg.interview-remind-window-minutes 控制，默认 60。</p>
 */
@Component
public class AppointmentRemindScheduler {

    @Value("${ruoyi.msg.interview-remind-window-minutes:60}")
    private long windowMinutes;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private EmailService emailService;

    @Scheduled(fixedDelay = 60_000L)
    public void remindUpcomingInterviews() {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT a.apt_id AS aptId, a.apt_start_time AS startTime, a.apt_meeting_url AS meetingUrl, " +
            "p.pos_title AS positionTitle, u.user_id AS userId, u.nick_name AS nickName, u.email AS email " +
            "FROM t_sch_appointment a " +
            "LEFT JOIN t_tal t ON a.apt_candidate_id = t.tal_id " +
            "LEFT JOIN sys_user u ON t.tal_user_id = u.user_id " +
            "LEFT JOIN t_pos p ON a.apt_position_id = p.pos_id " +
            "WHERE a.apt_status IN (0, 1) AND a.apt_notified = 0 " +
            "AND a.apt_start_time >= NOW() " +
            "AND a.apt_start_time <= DATE_ADD(NOW(), INTERVAL ? MINUTE)",
            windowMinutes);

        for (Map<String, Object> row : rows) {
            Long aptId = ((Number) row.get("aptId")).longValue();
            String email = row.get("email") == null ? null : String.valueOf(row.get("email")).trim();
            if (email == null || email.isEmpty()) {
                writeRecord(row, "email", "1", "缺少候选人邮箱，未发送");
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
                jdbcTemplate.update("UPDATE t_sch_appointment SET apt_notified = 1 WHERE apt_id = ?", aptId);
                writeRecord(row, "email", "0", null);
            } else {
                writeRecord(row, "email", "1", "邮件投递失败（SMTP认证或网络异常）");
            }
        }
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
