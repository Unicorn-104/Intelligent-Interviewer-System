package com.ruoyi.web.controller.system;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * AI长期记忆管理
 */
@RestController
@RequestMapping("/system/aiMemory")
public class AiMemoryController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /** 查询AI记忆列表 */
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) Long userId,
                              @RequestParam(required = false) String memoryType) {
        startPage();
        StringBuilder sql = new StringBuilder("SELECT id, user_id as userId, memory_type as memoryType, content, status, created_at as createdAt FROM t_capp_ai_memory_item WHERE 1=1");
        Map<String, Object> params = new HashMap<>();
        if (userId != null) {
            sql.append(" AND user_id = ?");
            params.put("userId", userId);
        }
        if (memoryType != null && !memoryType.isEmpty()) {
            sql.append(" AND memory_type = ?");
            params.put("memoryType", memoryType);
        }
        sql.append(" ORDER BY created_at DESC");
        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql.toString(), params.values().toArray());
        return getDataTable(list);
    }

    /** 删除AI记忆 */
    @DeleteMapping("/{id}")
    public AjaxResult remove(@PathVariable String id) {
        // 软删除：改状态为DELETED
        jdbcTemplate.update("UPDATE t_capp_ai_memory_item SET status = 'DELETED' WHERE id = ?", id);
        return AjaxResult.success();
    }
}
