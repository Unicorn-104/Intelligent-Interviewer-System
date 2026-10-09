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
 * 问题管理Controller
 */
@RestController
@RequestMapping("/content/question")
public class ContentQuestionController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('content:question:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT cq_id as id, cq_title as title, cq_category_id as categoryId, " +
            "cq_content as content, cq_answer as answer, cq_view_count as viewCount, " +
            "cq_status as status, cq_create_time as createTime FROM t_content_question ORDER BY cq_create_time DESC"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> body) {
        String title = (String) body.get("title");
        if (title == null || title.trim().isEmpty()) {
            return AjaxResult.error("问题标题不能为空");
        }
        String content = (String) body.getOrDefault("content", "");
        String answer = (String) body.getOrDefault("answer", "");
        jdbcTemplate.update(
            "INSERT INTO t_content_question (cq_title, cq_content, cq_answer) VALUES (?, ?, ?)",
            title, content, answer
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('content:question:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("id");
        if (id == null) {
            return AjaxResult.error("问题ID不能为空");
        }
        String title = (String) body.get("title");
        String content = (String) body.getOrDefault("content", "");
        String answer = (String) body.getOrDefault("answer", "");
        jdbcTemplate.update(
            "UPDATE t_content_question SET cq_title = ?, cq_content = ?, cq_answer = ? WHERE cq_id = ?",
            title, content, answer, id
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('content:question:remove')")
    @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_content_question WHERE cq_id = ?", id);
        }
        return AjaxResult.success();
    }
}
