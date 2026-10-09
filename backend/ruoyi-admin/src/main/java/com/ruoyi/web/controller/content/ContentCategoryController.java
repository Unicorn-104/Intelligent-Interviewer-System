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
 * 内容分类管理Controller
 */
@RestController
@RequestMapping("/content/category")
public class ContentCategoryController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /**
     * 查询内容分类列表
     */
    @PreAuthorize("@ss.hasPermi('content:category:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT cca_id as id, cca_name as name, cca_parent_id as parentId, cca_sort as sort, " +
            "cca_status as status, cca_create_time as createTime FROM t_content_category ORDER BY cca_sort"
        );
        return getDataTable(list);
    }

    /**
     * 新增内容分类
     */
    @PreAuthorize("@ss.hasPermi('content:category:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        if (name == null || name.trim().isEmpty()) {
            return AjaxResult.error("分类名称不能为空");
        }
        Object parentId = body.getOrDefault("parentId", 0);
        Object sort = body.getOrDefault("sort", 0);
        jdbcTemplate.update(
            "INSERT INTO t_content_category (cca_name, cca_parent_id, cca_sort) VALUES (?, ?, ?)",
            name, parentId, sort
        );
        return AjaxResult.success();
    }

    /**
     * 修改内容分类
     */
    @PreAuthorize("@ss.hasPermi('content:category:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("id");
        if (id == null) {
            return AjaxResult.error("分类ID不能为空");
        }
        String name = (String) body.get("name");
        Object sort = body.getOrDefault("sort", 0);
        jdbcTemplate.update(
            "UPDATE t_content_category SET cca_name = ?, cca_sort = ? WHERE cca_id = ?",
            name, sort, id
        );
        return AjaxResult.success();
    }

    /**
     * 删除内容分类
     */
    @PreAuthorize("@ss.hasPermi('content:category:remove')")
    @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_content_category WHERE cca_id = ?", id);
        }
        return AjaxResult.success();
    }
}
