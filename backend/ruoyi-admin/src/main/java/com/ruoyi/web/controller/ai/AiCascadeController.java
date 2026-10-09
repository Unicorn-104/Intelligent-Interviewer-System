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
 * AI级联规则管理
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/cascade")
public class AiCascadeController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('ai:cascade:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT cac_id as ruleId, cac_name as ruleName, cac_trigger_type as triggerType, " +
            "cac_priority as priority, cac_status as status, create_time as createTime " +
            "FROM t_ai_cascade ORDER BY cac_priority DESC"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('ai:cascade:query')")
    @GetMapping("/{ruleId}")
    public AjaxResult getInfo(@PathVariable("ruleId") Long ruleId) {
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT cac_id, cac_name, cac_trigger_type, cac_condition, cac_action, cac_priority, cac_status, create_by, create_time, update_by, update_time FROM t_ai_cascade WHERE cac_id = ?", ruleId
        );
        if (list.isEmpty()) {
            return error("规则不存在");
        }
        return success(list.get(0));
    }

    @PreAuthorize("@ss.hasPermi('ai:cascade:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> data) {
        String ruleName = (String) data.get("ruleName");
        if (ruleName == null || ruleName.trim().isEmpty()) {
            return AjaxResult.error("规则名称不能为空");
        }
        String triggerType = (String) data.get("triggerType");
        if (triggerType == null || triggerType.trim().isEmpty()) {
            return AjaxResult.error("触发类型不能为空");
        }
        jdbcTemplate.update(
            "INSERT INTO t_ai_cascade (cac_name, cac_trigger_type, cac_condition, cac_action, cac_priority, cac_status, create_by) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            ruleName, triggerType, data.get("condition"),
            data.get("action"), data.get("priority") != null ? data.get("priority") : 0, "0", getUsername()
        );
        return success();
    }

    @PreAuthorize("@ss.hasPermi('ai:cascade:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> data) {
        Object ruleIdObj = data.get("ruleId");
        if (ruleIdObj == null) {
            return AjaxResult.error("规则ID不能为空");
        }
        String ruleName = (String) data.get("ruleName");
        if (ruleName == null || ruleName.trim().isEmpty()) {
            return AjaxResult.error("规则名称不能为空");
        }
        jdbcTemplate.update(
            "UPDATE t_ai_cascade SET cac_name = ?, cac_trigger_type = ?, cac_condition = ?, " +
            "cac_action = ?, cac_priority = ?, update_by = ? WHERE cac_id = ?",
            ruleName, data.get("triggerType"), data.get("condition"),
            data.get("action"), data.get("priority"), getUsername(), ruleIdObj
        );
        return success();
    }

    @PreAuthorize("@ss.hasPermi('ai:cascade:remove')")
    @Transactional(rollbackFor = Exception.class)
    @DeleteMapping("/{ruleIds}")
    public AjaxResult remove(@PathVariable Long[] ruleIds) {
        for (Long id : ruleIds) {
            jdbcTemplate.update("DELETE FROM t_ai_cascade WHERE cac_id = ?", id);
        }
        return success();
    }
}
