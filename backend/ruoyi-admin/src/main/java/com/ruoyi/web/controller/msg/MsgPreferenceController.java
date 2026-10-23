package com.ruoyi.web.controller.msg;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;

import java.util.*;

/**
 * 通知偏好设置Controller（每用户一行，App/邮件/短信三开关）
 */
@RestController
@RequestMapping("/msg/preference")
public class MsgPreferenceController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /** 列表：join 用户表返回昵称，支持用户名称模糊筛选 */
    @PreAuthorize("@ss.hasPermi('msg:preference:list')")
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String userName) {
        startPage();
        StringBuilder sql = new StringBuilder(
            "SELECT p.prf_id AS preferenceId, p.prf_user_id AS userId, u.nick_name AS userName, " +
            "p.prf_enabled_app AS enabledApp, p.prf_enabled_email AS enabledEmail, " +
            "p.prf_enabled_sms AS enabledSms, p.prf_updated_at AS updateTime " +
            "FROM t_msg_preference p LEFT JOIN sys_user u ON p.prf_user_id = u.user_id WHERE 1=1 ");
        List<Object> args = new ArrayList<>();
        if (userName != null && !userName.trim().isEmpty()) {
            sql.append("AND u.nick_name LIKE ? ");
            args.add("%" + userName.trim() + "%");
        }
        sql.append("ORDER BY p.prf_updated_at DESC");
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql.toString(), args.toArray());
        return getDataTable(rows);
    }

    /** 详情 */
    @PreAuthorize("@ss.hasPermi('msg:preference:list')")
    @GetMapping("/{id}")
    public AjaxResult getById(@PathVariable Long id) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT p.prf_id AS preferenceId, p.prf_user_id AS userId, u.nick_name AS userName, " +
            "p.prf_enabled_app AS enabledApp, p.prf_enabled_email AS enabledEmail, " +
            "p.prf_enabled_sms AS enabledSms, p.prf_updated_at AS updateTime " +
            "FROM t_msg_preference p LEFT JOIN sys_user u ON p.prf_user_id = u.user_id WHERE p.prf_id = ?", id);
        if (rows.isEmpty()) {
            return AjaxResult.error("偏好记录不存在");
        }
        return success(rows.get(0));
    }

    /** 更新三开关 */
    @PreAuthorize("@ss.hasPermi('msg:preference:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("preferenceId");
        if (id == null) return AjaxResult.error("偏好ID不能为空");
        Integer app = body.get("enabledApp") != null ? Integer.valueOf(body.get("enabledApp").toString()) : 1;
        Integer email = body.get("enabledEmail") != null ? Integer.valueOf(body.get("enabledEmail").toString()) : 1;
        Integer sms = body.get("enabledSms") != null ? Integer.valueOf(body.get("enabledSms").toString()) : 0;
        jdbcTemplate.update(
            "UPDATE t_msg_preference SET prf_enabled_app = ?, prf_enabled_email = ?, prf_enabled_sms = ?, prf_updated_at = NOW() WHERE prf_id = ?",
            app, email, sms, id);
        return AjaxResult.success();
    }

    /** 按渠道翻转开关：channel = app / email / sms，按 userId */
    @PreAuthorize("@ss.hasPermi('msg:preference:edit')")
    @PutMapping("/toggleChannel")
    public AjaxResult toggleChannel(@RequestBody Map<String, Object> body) {
        Object userId = body.get("userId");
        String channel = (String) body.get("channel");
        if (userId == null) return AjaxResult.error("用户ID不能为空");
        if (channel == null) return AjaxResult.error("渠道不能为空");
        String column;
        switch (channel) {
            case "email": column = "prf_enabled_email"; break;
            case "sms": column = "prf_enabled_sms"; break;
            default: column = "prf_enabled_app"; break;
        }
        jdbcTemplate.update(
            "UPDATE t_msg_preference SET " + column + " = 1 - " + column + ", prf_updated_at = NOW() WHERE prf_user_id = ?",
            userId);
        return AjaxResult.success();
    }
}
