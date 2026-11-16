package com.ruoyi.web.controller.biz;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 平台运营 - IM沟通记录 Controller
 */
@RestController
@RequestMapping("/biz/im")
public class BizImController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('biz:im:list')")
    @GetMapping("/sessions")
    public TableDataInfo listSessions() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT s.ims_id, s.ims_last_message, s.ims_last_message_at, s.ims_created_at, " +
            "u1.nick_name as user_a, u2.nick_name as user_b " +
            "FROM t_im_session s " +
            "LEFT JOIN sys_user u1 ON s.ims_user_a_id = u1.user_id " +
            "LEFT JOIN sys_user u2 ON s.ims_user_b_id = u2.user_id " +
            "ORDER BY s.ims_last_message_at DESC");
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:im:list')")
    @GetMapping("/messages/{sessionId}")
    public AjaxResult messages(@PathVariable Long sessionId) {
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT imsg_id, imsg_sender_id, imsg_type, imsg_content, imsg_created_at " +
            "FROM t_im_message WHERE imsg_session_id=? ORDER BY imsg_created_at ASC", sessionId);
        return success(list);
    }
}
