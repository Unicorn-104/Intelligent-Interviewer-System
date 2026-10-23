package com.ruoyi.web.controller.msg;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.service.EmailService;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 消息发送记录Controller
 */
@RestController
@RequestMapping("/msg/record")
public class MsgRecordController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private EmailService emailService;

    /**
     * 发送记录列表：支持接收人模糊、渠道、状态、发送时间区间筛选
     */
    @PreAuthorize("@ss.hasPermi('msg:record:list')")
    @GetMapping("/list")
    public TableDataInfo list(
            @RequestParam(required = false) String receiver,
            @RequestParam(required = false) String channel,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String beginTime,
            @RequestParam(required = false) String endTime) {
        startPage();

        StringBuilder sql = new StringBuilder(
            "SELECT mr_id AS recordId, mr_user_name AS receiver, mr_contact AS contact, " +
            "mr_channel AS channel, mr_content AS content, mr_status AS status, " +
            "mr_fail_reason AS failReason, mr_create_time AS sendTime, t.tpl_title AS templateName " +
            "FROM t_msg_record r LEFT JOIN t_msg_template t ON r.mr_template_id = t.tpl_id WHERE 1=1 ");

        List<Object> args = new ArrayList<>();
        if (receiver != null && !receiver.trim().isEmpty()) {
            sql.append("AND r.mr_user_name LIKE ? ");
            args.add("%" + receiver.trim() + "%");
        }
        if (channel != null && !channel.trim().isEmpty()) {
            sql.append("AND r.mr_channel = ? ");
            args.add(channel);
        }
        if (status != null && !status.trim().isEmpty()) {
            sql.append("AND r.mr_status = ? ");
            args.add(status);
        }
        if (beginTime != null && !beginTime.trim().isEmpty()) {
            sql.append("AND r.mr_create_time >= ? ");
            args.add(beginTime);
        }
        if (endTime != null && !endTime.trim().isEmpty()) {
            sql.append("AND r.mr_create_time <= ? ");
            args.add(endTime);
        }
        sql.append("ORDER BY r.mr_create_time DESC");

        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql.toString(), args.toArray());
        return getDataTable(list);
    }

    /**
     * 发送记录统计：总数 / 成功 / 失败
     */
    @PreAuthorize("@ss.hasPermi('msg:record:list')")
    @GetMapping("/stats")
    public AjaxResult stats(
            @RequestParam(required = false) String channel,
            @RequestParam(required = false) String beginTime,
            @RequestParam(required = false) String endTime) {
        StringBuilder where = new StringBuilder(" WHERE 1=1 ");
        List<Object> args = new ArrayList<>();
        if (channel != null && !channel.trim().isEmpty()) {
            where.append("AND mr_channel = ? ");
            args.add(channel);
        }
        if (beginTime != null && !beginTime.trim().isEmpty()) {
            where.append("AND mr_create_time >= ? ");
            args.add(beginTime);
        }
        if (endTime != null && !endTime.trim().isEmpty()) {
            where.append("AND mr_create_time <= ? ");
            args.add(endTime);
        }
        Map<String, Object> row = jdbcTemplate.queryForMap(
            "SELECT COUNT(*) AS total, SUM(CASE WHEN mr_status = '0' THEN 1 ELSE 0 END) AS success, " +
            "SUM(CASE WHEN mr_status = '1' THEN 1 ELSE 0 END) AS fail FROM t_msg_record" + where,
            args.toArray());
        Map<String, Object> data = new HashMap<>();
        data.put("total", row.get("total") == null ? 0 : ((Number) row.get("total")).longValue());
        data.put("success", row.get("success") == null ? 0 : ((Number) row.get("success")).longValue());
        data.put("fail", row.get("fail") == null ? 0 : ((Number) row.get("fail")).longValue());
        return success(data);
    }

    /**
     * 重试发送：
     * - email 渠道复用全局 SMTP（EmailService）真实投递，成功置成功、失败置失败并记录原因；
     * - sms/system 无真实通道，仅清空失败原因并标记待重试，不伪造投递结果。
     */
    @PreAuthorize("@ss.hasPermi('msg:record:edit')")
    @PostMapping("/resend")
    public AjaxResult resend(@RequestBody Map<String, Object> body) {
        Object recordId = body.get("recordId");
        if (recordId == null) {
            return AjaxResult.error("记录ID不能为空");
        }
        Map<String, Object> row = jdbcTemplate.queryForMap(
            "SELECT mr_contact AS contact, mr_channel AS channel, mr_content AS content " +
            "FROM t_msg_record WHERE mr_id = ?", recordId);
        if (row == null) {
            return AjaxResult.error("记录不存在");
        }

        String channel = String.valueOf(row.get("channel"));
        if ("email".equalsIgnoreCase(channel)) {
            String contact = row.get("contact") == null ? null : row.get("contact").toString();
            if (contact == null || contact.trim().isEmpty()) {
                return AjaxResult.error("缺少收件邮箱，无法发送");
            }
            boolean ok = emailService.sendSimpleMail(contact.trim(), "消息通知", String.valueOf(row.get("content")));
            if (ok) {
                jdbcTemplate.update(
                    "UPDATE t_msg_record SET mr_status = '0', mr_fail_reason = NULL WHERE mr_id = ?", recordId);
                return AjaxResult.success("邮件已发送成功");
            }
            jdbcTemplate.update(
                "UPDATE t_msg_record SET mr_status = '1', mr_fail_reason = ? WHERE mr_id = ?",
                "邮件投递失败（SMTP认证或网络异常）", recordId);
            return AjaxResult.error("邮件发送失败，请检查SMTP配置或网络");
        }

        // sms / system：当前无真实发送通道，仅标记待重试
        jdbcTemplate.update(
            "UPDATE t_msg_record SET mr_fail_reason = NULL WHERE mr_id = ?", recordId);
        return AjaxResult.success("已标记待重试（短信/站内暂未接入真实发送通道）");
    }
}
