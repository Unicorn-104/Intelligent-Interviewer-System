package com.ruoyi.web.controller.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import java.util.*;

/**
 * AI评分卡配置（对齐前端 /ai/scorecard 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/scorecard")
public class AiScorecardController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('ai:scorecard:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        String sql = "SELECT sc_id, sc_name, sc_direction, sc_dimensions, sc_status, sc_created_at FROM t_scorecard ORDER BY sc_id DESC";
        List<Map<String, Object>> rawList = jdbcTemplate.queryForList(sql);

        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> row : rawList) {
            Map<String, Object> item = new HashMap<>();
            item.put("cardId", row.get("sc_id"));
            item.put("cardName", row.get("sc_name"));
            item.put("jobDirection", row.get("sc_direction"));
            try {
                String dims = (String) row.get("sc_dimensions");
                if (dims != null && !dims.isEmpty()) {
                    item.put("dimensions", com.alibaba.fastjson2.JSON.parse(dims));
                } else {
                    item.put("dimensions", new ArrayList<>());
                }
            } catch (Exception e) {
                item.put("dimensions", new ArrayList<>());
            }
            item.put("status", row.get("sc_status"));
            result.add(item);
        }
        return getDataTable(result);
    }

    @PreAuthorize("@ss.hasPermi('ai:scorecard:query')")
    @GetMapping("/{cardId}")
    public AjaxResult getInfo(@PathVariable("cardId") Long cardId) {
        String sql = "SELECT sc_id, sc_name, sc_direction, sc_dimensions, sc_status, sc_created_at FROM t_scorecard WHERE sc_id = ?";
        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql, cardId);
        if (list.isEmpty()) {
            return error("评分卡不存在");
        }
        return success(list.get(0));
    }

    @PreAuthorize("@ss.hasPermi('ai:scorecard:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> data) {
        String name = (String) data.get("cardName");
        if (name == null || name.trim().isEmpty()) {
            return AjaxResult.error("评分卡名称不能为空");
        }
        String direction = (String) data.get("jobDirection");
        Object dimensions = data.get("dimensions");
        String dimsJson = dimensions != null ? com.alibaba.fastjson2.JSON.toJSONString(dimensions) : "[]";
        Object statusObj = data.get("status");
        Integer status = statusObj != null ? Integer.valueOf(statusObj.toString()) : 1;

        int rows = jdbcTemplate.update(
            "INSERT INTO t_scorecard (sc_name, sc_direction, sc_dimensions, sc_status) VALUES (?, ?, ?, ?)",
            name, direction, dimsJson, status
        );
        return toAjax(rows);
    }

    @PreAuthorize("@ss.hasPermi('ai:scorecard:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> data) {
        Object cardIdObj = data.get("cardId");
        if (cardIdObj == null) {
            return AjaxResult.error("评分卡ID不能为空");
        }
        Long cardId = ((Number) cardIdObj).longValue();
        String name = (String) data.get("cardName");
        String direction = (String) data.get("jobDirection");
        Object dimensions = data.get("dimensions");
        String dimsJson = dimensions != null ? com.alibaba.fastjson2.JSON.toJSONString(dimensions) : "[]";
        Object statusObj = data.get("status");
        Integer status = statusObj != null ? Integer.valueOf(statusObj.toString()) : 1;

        int rows = jdbcTemplate.update(
            "UPDATE t_scorecard SET sc_name = ?, sc_direction = ?, sc_dimensions = ?, sc_status = ? WHERE sc_id = ?",
            name, direction, dimsJson, status, cardId
        );
        return toAjax(rows);
    }

    @PreAuthorize("@ss.hasPermi('ai:scorecard:remove')")
    @Transactional(rollbackFor = Exception.class)
    @DeleteMapping("/{cardIds}")
    public AjaxResult remove(@PathVariable Long[] cardIds) {
        for (Long id : cardIds) {
            jdbcTemplate.update("DELETE FROM t_scorecard WHERE sc_id = ?", id);
        }
        return success();
    }
}
