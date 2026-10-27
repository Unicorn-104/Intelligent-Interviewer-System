package com.ruoyi.web.controller.admin;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * AI Agent 事件监控
 */
@RestController
@RequestMapping("/admin/aiagent")
public class AiAgentMonitorController extends BaseController {

    @Autowired
    private JdbcTemplate jdbc;

    /** 概览：今日事件数、失败数、按类型分布 */
    @GetMapping("/overview")
    public AjaxResult overview() {
        Map<String, Object> res = new HashMap<>();
        res.put("todayTotal", jdbc.queryForObject(
                "SELECT COUNT(*) FROM t_capp_ai_event WHERE DATE(created_at)=CURDATE()", Long.class));
        res.put("total", jdbc.queryForObject("SELECT COUNT(*) FROM t_capp_ai_event", Long.class));
        List<Map<String, Object>> byType = jdbc.queryForList(
                "SELECT event_type, COUNT(*) c FROM t_capp_ai_event GROUP BY event_type");
        res.put("byType", byType);
        List<Map<String, Object>> byDay = jdbc.queryForList(
                "SELECT DATE(created_at) d, COUNT(*) c FROM t_capp_ai_event WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) GROUP BY DATE(created_at) ORDER BY d");
        res.put("byDay", byDay);
        return AjaxResult.success(res);
    }

    /** 事件列表 */
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String eventType,
                             @RequestParam(required = false) String keyword) {
        startPage();
        StringBuilder sql = new StringBuilder("SELECT id, run_id, event_type, LEFT(data_json, 500) AS data_preview, created_at FROM t_capp_ai_event WHERE 1=1");
        List<Object> args = new java.util.ArrayList<>();
        if (eventType != null && !eventType.isEmpty()) {
            sql.append(" AND event_type=?");
            args.add(eventType);
        }
        if (keyword != null && !keyword.isEmpty()) {
            sql.append(" AND data_json LIKE ?");
            args.add("%" + keyword + "%");
        }
        sql.append(" ORDER BY id DESC");
        List<Map<String, Object>> list = jdbc.queryForList(sql.toString(), args.toArray());
        return getDataTable(list);
    }

    /** 按 run_id 查完整事件链 */
    @GetMapping("/trace")
    public AjaxResult trace(@RequestParam String runId) {
        List<Map<String, Object>> list = jdbc.queryForList(
                "SELECT id, event_type, data_json, created_at FROM t_capp_ai_event WHERE run_id=? ORDER BY id", runId);
        return AjaxResult.success(list);
    }
}
