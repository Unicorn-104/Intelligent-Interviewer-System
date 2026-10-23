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
 * 渠道配置Controller
 */
@RestController
@RequestMapping("/msg/channel")
public class MsgChannelController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('msg:channel:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT mc_id AS channelId, mc_name AS channelName, mc_type AS channelType, " +
            "mc_config AS config, mc_status AS status, mc_create_time AS createTime, " +
            "'' AS provider, 0 AS dailyLimit, '' AS remark FROM t_msg_channel ORDER BY mc_create_time DESC"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('msg:channel:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> body) {
        String name = (String) body.get("name");
        if (name == null || name.trim().isEmpty()) {
            return AjaxResult.error("渠道名称不能为空");
        }
        String type = (String) body.get("type");
        if (type == null || type.trim().isEmpty()) {
            return AjaxResult.error("渠道类型不能为空");
        }
        String config = (String) body.getOrDefault("config", "{}");
        jdbcTemplate.update(
            "INSERT INTO t_msg_channel (mc_name, mc_type, mc_config) VALUES (?, ?, ?)",
            name, type, config
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('msg:channel:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("id");
        if (id == null) {
            return AjaxResult.error("渠道ID不能为空");
        }
        String name = (String) body.get("name");
        String config = (String) body.getOrDefault("config", "{}");
        jdbcTemplate.update(
            "UPDATE t_msg_channel SET mc_name = ?, mc_config = ? WHERE mc_id = ?",
            name, config, id
        );
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('msg:channel:remove')")
    @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_msg_channel WHERE mc_id = ?", id);
        }
        return AjaxResult.success();
    }

    /** 启用 / 停用渠道 */
    @PreAuthorize("@ss.hasPermi('msg:channel:edit')")
    @PutMapping("/toggle")
    public AjaxResult toggle(@RequestBody Map<String, Object> body) {
        Object channelId = body.get("channelId");
        if (channelId == null) {
            return AjaxResult.error("渠道ID不能为空");
        }
        jdbcTemplate.update("UPDATE t_msg_channel SET mc_status = 1 - mc_status WHERE mc_id = ?", channelId);
        return AjaxResult.success();
    }
}
