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
 * Offer 接受即将到期提醒定时任务。
 *
 * <p>每分钟扫描「已发送待接受（ofr_status=0）且未提醒」的 Offer，对接受到期时间落在未来
 * 配置窗口内的场次，复用全局 SMTP（EmailService）提醒候选人尽快接受；成功后置已提醒标记
 * 并写发送台账，失败保留未标记由下一轮重试。只读扫描业务表，不修改企业端写逻辑。</p>
 *
 * <p>到期窗口小时数由配置项 ruoyi.msg.offer-deadline-remind-hours 控制，默认 24。</p>
 */
@Component
public class OfferExpireRemindScheduler {

    @Value("${ruoyi.msg.offer-deadline-remind-hours:24}")
    private long deadlineHours;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private EmailService emailService;

    @Scheduled(fixedDelay = 60_000L)
    public void remindExpiringOffers() {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT o.ofr_id AS offerId, o.ofr_deadline AS deadline, p.pos_title AS positionTitle, " +
            "u.nick_name AS nickName, u.email AS email " +
            "FROM t_off_offer o " +
            "LEFT JOIN t_tal t ON o.ofr_candidate_id = t.tal_id " +
            "LEFT JOIN sys_user u ON t.tal_user_id = u.user_id " +
            "LEFT JOIN t_pos p ON o.ofr_position_id = p.pos_id " +
            "WHERE o.ofr_status = 0 AND o.ofr_notified = 0 " +
            "AND o.ofr_deadline IS NOT NULL " +
            "AND o.ofr_deadline >= NOW() " +
            "AND o.ofr_deadline <= DATE_ADD(NOW(), INTERVAL ? HOUR)",
            deadlineHours);

        for (Map<String, Object> row : rows) {
            Long offerId = ((Number) row.get("offerId")).longValue();
            String email = row.get("email") == null ? null : String.valueOf(row.get("email")).trim();
            if (email == null || email.isEmpty()) {
                writeRecord(row, "1", "缺少候选人邮箱，未发送");
                continue;
            }
            String name = row.get("nickName") == null ? "候选人" : String.valueOf(row.get("nickName"));
            String position = row.get("positionTitle") == null ? "" : String.valueOf(row.get("positionTitle"));
            String deadline = row.get("deadline") == null ? "" : String.valueOf(row.get("deadline"));
            String subject = "Offer 接受即将到期提醒 - " + position;
            String content = name + "您好：您收到的岗位「" + position + "」Offer 接受将于 "
                    + deadline + " 截止，请尽快确认接受，逾期视为放弃。";

            boolean ok = emailService.sendSimpleMail(email, subject, content);
            if (ok) {
                jdbcTemplate.update("UPDATE t_off_offer SET ofr_notified = 1 WHERE ofr_id = ?", offerId);
                writeRecord(row, "0", null);
            } else {
                writeRecord(row, "1", "邮件投递失败（SMTP认证或网络异常）");
            }
        }
    }

    /** 写发送台账 t_msg_record */
    private void writeRecord(Map<String, Object> row, String status, String failReason) {
        jdbcTemplate.update(
            "INSERT INTO t_msg_record (mr_user_name, mr_contact, mr_channel, mr_content, mr_status, mr_fail_reason) " +
            "VALUES (?, ?, ?, ?, ?, ?)",
            row.get("nickName"), row.get("email"), "email",
            "Offer到期提醒：" + row.get("positionTitle") + " 截止 " + row.get("deadline"),
            status, failReason);
    }
}
