package com.ruoyi.web.controller.system;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import java.util.*;

/**
 * 隐私设置管理
 *
 * @author TQY
 */
@RestController
@RequestMapping("/system/privacy")
public class SystemPrivacyController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('system:privacy:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT priv_id as privacyId, priv_key as privacyKey, priv_value as privacyValue, " +
            "priv_desc as description, priv_type as privacyType, create_time as createTime " +
            "FROM t_system_privacy ORDER BY priv_type, priv_id"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('system:privacy:query')")
    @GetMapping("/{privacyId}")
    public AjaxResult getInfo(@PathVariable("privacyId") Long privacyId) {
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT * FROM t_system_privacy WHERE priv_id = ?", privacyId
        );
        if (list.isEmpty()) {
            return error("隐私配置不存在");
        }
        return success(list.get(0));
    }

    @PreAuthorize("@ss.hasPermi('system:privacy:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> data) {
        String privacyKey = (String) data.get("privacyKey");
        if (privacyKey == null || privacyKey.trim().isEmpty()) {
            return AjaxResult.error("配置键不能为空");
        }
        jdbcTemplate.update(
            "INSERT INTO t_system_privacy (priv_key, priv_value, priv_desc, priv_type) VALUES (?, ?, ?, ?)",
            privacyKey, data.get("privacyValue"), data.get("description"), data.get("privacyType")
        );
        return success();
    }

    @PreAuthorize("@ss.hasPermi('system:privacy:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> data) {
        Object privacyIdObj = data.get("privacyId");
        if (privacyIdObj == null) {
            return AjaxResult.error("配置ID不能为空");
        }
        jdbcTemplate.update(
            "UPDATE t_system_privacy SET priv_value = ?, priv_desc = ? WHERE priv_id = ?",
            data.get("privacyValue"), data.get("description"), privacyIdObj
        );
        return success();
    }

    @PreAuthorize("@ss.hasPermi('system:privacy:remove')")
    @DeleteMapping("/{privacyIds}")
    public AjaxResult remove(@PathVariable Long[] privacyIds) {
        for (Long id : privacyIds) {
            jdbcTemplate.update("DELETE FROM t_system_privacy WHERE priv_id = ?", id);
        }
        return success();
    }
}
