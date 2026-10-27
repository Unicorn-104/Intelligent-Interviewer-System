package com.ruoyi.web.controller.admin;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/** 面试 AI 对话回放 */
@RestController
@RequestMapping("/admin/interview/dialogue")
public class InterviewDialogueController extends BaseController {

    @Autowired
    private JdbcTemplate jdbc;

    @GetMapping("/list")
    public AjaxResult list(@RequestParam Long sessionId) {
        List<Map<String, Object>> list = jdbc.queryForList(
                "SELECT dlg_id, dlg_order, dlg_role, dlg_type, dlg_content, dlg_intent, dlg_created_at " +
                "FROM t_int_dialogue WHERE dlg_session_id=? ORDER BY dlg_order", sessionId);
        return AjaxResult.success(list);
    }
}
