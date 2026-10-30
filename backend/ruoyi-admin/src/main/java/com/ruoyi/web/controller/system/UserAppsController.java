package com.ruoyi.web.controller.system;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;

import java.util.List;
import java.util.Map;

/** 用户投递记录 */
@RestController
@RequestMapping("/system/user-apps")
public class UserAppsController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('system:user:query')")
    @GetMapping("/{userId}")
    public AjaxResult list(@PathVariable Long userId) {
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT a.app_id AS appId, a.app_status AS status, a.app_created_at AS created, " +
            "a.app_updated_at AS updated, a.app_matched_score AS score, " +
            "p.pos_title AS posTitle, c.cmp_name AS companyName, " +
            "CASE a.app_status WHEN 0 THEN '待筛选' WHEN 1 THEN '初筛通过' WHEN 2 THEN '初筛淘汰' " +
            "WHEN 3 THEN '已约面' WHEN 4 THEN '待笔试' WHEN 5 THEN '笔试中' WHEN 6 THEN '笔试通过' " +
            "WHEN 7 THEN '笔试未通过' WHEN 8 THEN '笔试缺考' WHEN 9 THEN '已撤回' ELSE CONCAT('状态',a.app_status) END AS statusText " +
            "FROM t_app_record a " +
            "LEFT JOIN t_pos p ON p.pos_id = a.app_position_id " +
            "LEFT JOIN t_cmp c ON c.cmp_id = p.pos_company_id " +
            "WHERE a.app_candidate_id = ? " +
            "ORDER BY a.app_created_at DESC", userId);
        return success(list);
    }
}
