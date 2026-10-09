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
 * 帮助中心Controller
 */
@RestController
@RequestMapping("/content/help")
public class ContentHelpController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('content:help:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT ch_id as id, ch_title as title, ch_category as category, " +
            "ch_content as content, ch_sort as sort, ch_status as status, " +
            "ch_create_time as createTime FROM t_content_help ORDER BY ch_sort"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('content:help:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> body) {
        String title = (String) body.get("title");
        if (title == null || title.trim().isEmpty()) {
            return AjaxResult.error("标题不能为空");
        }
        String category = (String) body.getOrDefault("category", "");
        String content = (String) body.getOrDefault("content", "");
        jdbcTemplate.update(
            "INSERT INTO t_content_help (ch_title, ch_category, ch_content) VALUES (?, ?, ?)",
            title, category, content
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('content:help:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("id");
        if (id == null) {
            return AjaxResult.error("ID不能为空");
        }
        String title = (String) body.get("title");
        String category = (String) body.getOrDefault("category", "");
        String content = (String) body.getOrDefault("content", "");
        jdbcTemplate.update(
            "UPDATE t_content_help SET ch_title = ?, ch_category = ?, ch_content = ? WHERE ch_id = ?",
            title, category, content, id
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('content:help:remove')")
    @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_content_help WHERE ch_id = ?", id);
        }
        return AjaxResult.success();
    }
}
