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
 * 平台运营 - 入职管理 Controller
 */
@RestController
@RequestMapping("/biz/onboarding")
public class BizOnboardingController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('biz:onboarding:list')")
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String status,
                              @RequestParam(required = false) String keyword) {
        startPage();
        StringBuilder sql = new StringBuilder(
            "SELECT ob.obd_id, ob.obd_status, ob.obd_followup_record, ob.obd_expected_onboard_date, ob.obd_created_at, " +
            "v.candidate_name AS tal_name, v.phonenumber AS tal_phone, p.pos_title, c.cmp_name " +
            "FROM t_onboarding ob " +
            "LEFT JOIN v_candidate_overview v ON ob.obd_candidate_id = v.tal_id " +
            "LEFT JOIN t_off_offer o ON ob.obd_offer_id = o.ofr_id " +
            "LEFT JOIN t_pos p ON o.ofr_position_id = p.pos_id " +
            "LEFT JOIN t_cmp c ON p.pos_company_id = c.cmp_id " +
            "WHERE 1=1 ");
        if (status != null && !status.isEmpty()) {
            sql.append("AND ob.obd_status = ").append(status).append(" ");
        }
        if (keyword != null && !keyword.isEmpty()) {
            sql.append("AND (v.candidate_name LIKE '%").append(keyword).append("%' OR c.cmp_name LIKE '%").append(keyword).append("%') ");
        }
        sql.append("ORDER BY ob.obd_expected_onboard_date ASC");
        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql.toString());
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:onboarding:update')")
    @PutMapping("/status/{id}")
    public AjaxResult updateStatus(@PathVariable Long id,
                                   @RequestParam Integer status,
                                   @RequestParam(required = false) String followup) {
        jdbcTemplate.update("UPDATE t_onboarding SET obd_status=?, obd_followup_record=? WHERE obd_id=?", status, followup, id);
        return success();
    }
}
