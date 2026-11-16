package com.ruoyi.web.controller.biz;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 平台运营 - Offer管理 Controller
 */
@RestController
@RequestMapping("/biz/offer")
public class BizOfferController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('biz:offer:list')")
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String status,
                              @RequestParam(required = false) String keyword) {
        startPage();
        StringBuilder sql = new StringBuilder(
            "SELECT o.ofr_id, o.ofr_salary_offer, o.ofr_deadline, o.ofr_onboard_date, " +
            "o.ofr_approval_status, o.ofr_status, o.ofr_created_at, " +
            "v.candidate_name AS tal_name, v.phonenumber AS tal_phone, p.pos_title, c.cmp_name " +
            "FROM t_off_offer o " +
            "LEFT JOIN v_candidate_overview v ON o.ofr_candidate_id = v.tal_id " +
            "LEFT JOIN t_pos p ON o.ofr_position_id = p.pos_id " +
            "LEFT JOIN t_cmp c ON p.pos_company_id = c.cmp_id " +
            "WHERE 1=1 ");
        if (status != null && !status.isEmpty()) {
            sql.append("AND o.ofr_status = ").append(status).append(" ");
        }
        if (keyword != null && !keyword.isEmpty()) {
            sql.append("AND (v.candidate_name LIKE '%").append(keyword).append("%' OR c.cmp_name LIKE '%").append(keyword).append("%') ");
        }
        sql.append("ORDER BY o.ofr_created_at DESC");
        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql.toString());
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:offer:approve')")
    @PutMapping("/approve/{id}")
    public AjaxResult approve(@PathVariable Long id, @RequestParam Integer status) {
        jdbcTemplate.update("UPDATE t_off_offer SET ofr_approval_status=? WHERE ofr_id=?", status, id);
        return success();
    }

    @PreAuthorize("@ss.hasPermi('biz:offer:withdraw')")
    @PutMapping("/withdraw/{id}")
    public AjaxResult withdraw(@PathVariable Long id, @RequestParam(required = false) String reason) {
        // 与 enterprise_pc 口径对齐：ofr_status 6=已撤回（3 表示已过期）
        jdbcTemplate.update("UPDATE t_off_offer SET ofr_status=6, ofr_withdraw_reason=?, ofr_withdraw_at=NOW() WHERE ofr_id=?", reason, id);
        return success();
    }
}
