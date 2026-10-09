package com.ruoyi.web.controller.content;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;

import java.util.List;
import java.util.Map;

/**
 * 反馈处理Controller
 */
@RestController
@RequestMapping("/content/feedback")
public class ContentFeedbackController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('content:feedback:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT cf_id as id, cf_user_name as userName, cf_type as type, " +
            "cf_content as content, cf_contact as contact, cf_status as status, " +
            "cf_reply as reply, cf_create_time as createTime FROM t_content_feedback ORDER BY cf_create_time DESC"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('content:feedback:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("id");
        if (id == null) {
            return AjaxResult.error("反馈ID不能为空");
        }
        String reply = (String) body.getOrDefault("reply", "");
        String status = (String) body.getOrDefault("status", "1");
        jdbcTemplate.update(
            "UPDATE t_content_feedback SET cf_reply = ?, cf_status = ? WHERE cf_id = ?",
            reply, status, id
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('content:feedback:remove')")
    @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_content_feedback WHERE cf_id = ?", id);
        }
        return AjaxResult.success();
    }
}
