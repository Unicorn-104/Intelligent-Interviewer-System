package com.ruoyi.web.controller.admin;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** 数据看板 */
@RestController
@RequestMapping("/admin/dashboard")
public class OpsDashboardController extends BaseController {

    @Autowired
    private JdbcTemplate jdbc;

    @GetMapping("/overview")
    public AjaxResult overview() {
        Map<String, Object> res = new HashMap<>();
        // 候选人状态分布
        List<Map<String, Object>> talStatus = jdbc.queryForList(
                "SELECT tal_status, COUNT(*) c FROM t_tal GROUP BY tal_status ORDER BY tal_status");
        res.put("talStatus", talStatus);
        // 岗位城市分布
        List<Map<String, Object>> posCity = jdbc.queryForList(
                "SELECT pos_work_city city, COUNT(*) c FROM t_pos WHERE pos_work_city IS NOT NULL AND pos_work_city<>'' GROUP BY pos_work_city ORDER BY c DESC LIMIT 10");
        res.put("posCity", posCity);
        // 近7天投递量
        List<Map<String, Object>> appTrend = jdbc.queryForList(
                "SELECT DATE(app_created_at) d, COUNT(*) c FROM t_app_record WHERE app_created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) GROUP BY DATE(app_created_at) ORDER BY d");
        res.put("appTrend", appTrend);
        // 企业数量
        res.put("companyCount", jdbc.queryForObject("SELECT COUNT(*) FROM t_cmp", Long.class));
        // 岗位总数
        res.put("posCount", jdbc.queryForObject("SELECT COUNT(*) FROM t_pos", Long.class));
        return AjaxResult.success(res);
    }
}
