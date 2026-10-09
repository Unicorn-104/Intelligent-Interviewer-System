package com.ruoyi.web.controller.msg;

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
 * 消息模板管理Controller
 */
@RestController
@RequestMapping("/msg/template")
public class MsgTemplateController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('msg:template:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT tpl_id as id, tpl_code as code, tpl_title as title, tpl_content as content, " +
            "tpl_channel as channel, tpl_status as status, tpl_created_at as createTime " +
            "FROM t_msg_template ORDER BY tpl_created_at DESC"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('msg:template:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> body) {
        String code = (String) body.get("code");
        if (code == null || code.trim().isEmpty()) {
            return AjaxResult.error("模板编码不能为空");
        }
        String title = (String) body.get("title");
        if (title == null || title.trim().isEmpty()) {
            return AjaxResult.error("模板标题不能为空");
        }
        String content = (String) body.get("content");
        if (content == null || content.trim().isEmpty()) {
            return AjaxResult.error("模板内容不能为空");
        }
        jdbcTemplate.update(
            "INSERT INTO t_msg_template (tpl_code, tpl_title, tpl_content) VALUES (?, ?, ?)",
            code, title, content
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('msg:template:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("id");
        if (id == null) {
            return AjaxResult.error("模板ID不能为空");
        }
        String title = (String) body.get("title");
        String content = (String) body.get("content");
        jdbcTemplate.update(
            "UPDATE t_msg_template SET tpl_title = ?, tpl_content = ? WHERE tpl_id = ?",
            title, content, id
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('msg:template:remove')")
    @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_msg_template WHERE tpl_id = ?", id);
        }
        return AjaxResult.success();
    }
}
