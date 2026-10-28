package com.ruoyi.web.controller.msg;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.service.EmailService;

import java.util.*;

/**
 * 主动发消息：选接收人+渠道+内容
 */
@RestController
@RequestMapping("/msg/send")
public class MsgSendController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private EmailService emailService;

    /** 可选接收人列表：企业用户 */
    @PreAuthorize("@ss.hasPermi('msg:send:list')")
    @GetMapping("/recipients")
    public AjaxResult recipients() {
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT u.user_id AS userId, u.user_name AS userName, u.email AS email, u.phonenumber AS phone, " +
            "c.cmp_name AS companyName FROM sys_user u " +
            "LEFT JOIN t_cmp_binding cb ON cb.bnd_user_id = u.user_id " +
            "LEFT JOIN t_cmp c ON c.cmp_id = cb.bnd_company_id " +
            "WHERE u.del_flag = '0' " +
            "ORDER BY c.cmp_name, u.user_name LIMIT 500");
        return success(list);
    }

    /** 发送：type=email/inapp，targets=[userId...]，title/content */
    @PreAuthorize("@ss.hasPermi('msg:send:send')")
    @Log(title = "主动发消息", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult send(@RequestBody Map<String, Object> body) {
        String channel = String.valueOf(body.getOrDefault("channel", "inapp"));
        String title = String.valueOf(body.getOrDefault("title", "系统通知"));
        String content = String.valueOf(body.getOrDefault("content", ""));
        List<?> targets = (List<?>) body.getOrDefault("targets", Collections.emptyList());
        if (targets.isEmpty()) return error("请选择接收人");
        if (content.isEmpty()) return error("内容不能为空");

        int okCount = 0, failCount = 0;
        for (Object t : targets) {
            Long userId = Long.valueOf(t.toString());
            Map<String, Object> u = jdbcTemplate.queryForMap(
                "SELECT u.user_name, u.email, c.cmp_name FROM sys_user u " +
                "LEFT JOIN t_cmp_user cu ON cu.cu_user_id = u.user_id " +
                "LEFT JOIN t_cmp c ON c.cmp_id = cu.cu_company_id " +
                "WHERE u.user_id = ?", userId);

            boolean ok = false;
            if ("email".equalsIgnoreCase(channel)) {
                String email = u.get("email") == null ? "" : u.get("email").toString();
                if (!email.isEmpty()) {
                    ok = emailService.sendSimpleMail(email, title, content);
                }
            } else {
                // 站内信：直接写 t_msg_record
                jdbcTemplate.update(
                    "INSERT INTO t_msg_record (mr_channel, mr_contact, mr_subject, mr_content, mr_status, mr_create_time) " +
                    "VALUES (?, ?, ?, ?, '0', NOW())",
                    "inapp", String.valueOf(userId), title, content);
                ok = true;
            }
            if (ok) okCount++; else failCount++;
        }
        return success(Map.of("ok", okCount, "fail", failCount, "channel", channel));
    }
}
