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
 * 消息偏好设置Controller
 */
@RestController
@RequestMapping("/msg/preference")
public class MsgPreferenceController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('msg:preference:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT prf_id as id, prf_user_id as userId, prf_enabled_app as enabledApp, " +
            "prf_enabled_email as enabledEmail, prf_enabled_sms as enabledSms, prf_created_at as createTime " +
            "FROM t_msg_preference ORDER BY prf_created_at DESC"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('msg:preference:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("id");
        if (id == null) {
            return AjaxResult.error("偏好ID不能为空");
        }
        Integer enabledApp = body.get("enabledApp") != null ? Integer.valueOf(body.get("enabledApp").toString()) : 1;
        Integer enabledEmail = body.get("enabledEmail") != null ? Integer.valueOf(body.get("enabledEmail").toString()) : 1;
        Integer enabledSms = body.get("enabledSms") != null ? Integer.valueOf(body.get("enabledSms").toString()) : 0;
        jdbcTemplate.update(
            "UPDATE t_msg_preference SET prf_enabled_app = ?, prf_enabled_email = ?, prf_enabled_sms = ? WHERE prf_id = ?",
            enabledApp, enabledEmail, enabledSms, id
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('msg:preference:edit')")
    @PutMapping("/toggleChannel")
    public AjaxResult toggleChannel(@RequestBody Map<String, Object> body) {
        Object userId = body.get("userId");
        if (userId == null) {
            return AjaxResult.error("用户ID不能为空");
        }
        String channel = (String) body.get("channel");
        if (channel == null) {
            return AjaxResult.error("渠道不能为空");
        }
        // 根据渠道切换对应的开关
        String column = "prf_enabled_" + channel;
        jdbcTemplate.update(
            "UPDATE t_msg_preference SET " + column + " = 1 - " + column + " WHERE prf_user_id = ?",
            userId
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('msg:preference:edit')")
    @PutMapping("/toggleType")
    public AjaxResult toggleType(@RequestBody Map<String, Object> body) {
        Object userId = body.get("userId");
        if (userId == null) {
            return AjaxResult.error("用户ID不能为空");
        }
        String type = (String) body.get("type");
        if (type == null) {
            return AjaxResult.error("类型不能为空");
        }
        // 根据类型切换对应的开关
        String column = "prf_enabled_" + type;
        jdbcTemplate.update(
            "UPDATE t_msg_preference SET " + column + " = 1 - " + column + " WHERE prf_user_id = ?",
            userId
        );
        return AjaxResult.success();
    }
}
