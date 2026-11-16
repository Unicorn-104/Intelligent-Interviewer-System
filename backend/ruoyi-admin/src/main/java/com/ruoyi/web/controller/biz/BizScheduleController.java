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
 * 平台运营 - 面试预约调度 Controller
 */
@RestController
@RequestMapping("/biz/schedule")
public class BizScheduleController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('biz:schedule:list')")
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String status,
                              @RequestParam(required = false) String date) {
        startPage();
        StringBuilder sql = new StringBuilder(
            "SELECT a.apt_id, a.apt_start_time, a.apt_end_time, a.apt_status, a.apt_cancel_reason, " +
            "a.apt_meeting_url, a.apt_stage_name, v.candidate_name AS tal_name, v.phonenumber AS tal_phone, p.pos_title, c.cmp_name " +
            "FROM t_sch_appointment a " +
            "LEFT JOIN v_candidate_overview v ON a.apt_candidate_id = v.tal_id " +
            "LEFT JOIN t_pos p ON a.apt_position_id = p.pos_id " +
            "LEFT JOIN t_cmp c ON p.pos_company_id = c.cmp_id " +
            "WHERE 1=1 ");
        if (status != null && !status.isEmpty()) {
            sql.append("AND a.apt_status = ").append(status).append(" ");
        }
        if (date != null && !date.isEmpty()) {
            sql.append("AND DATE(a.apt_start_time) = '").append(date).append("' ");
        }
        sql.append("ORDER BY a.apt_start_time DESC");
        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql.toString());
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:schedule:update')")
    @PutMapping("/cancel/{id}")
    public AjaxResult cancel(@PathVariable Long id, @RequestParam(required = false) String reason) {
        jdbcTemplate.update("UPDATE t_sch_appointment SET apt_status=2, apt_cancel_reason=? WHERE apt_id=?", reason, id);
        return success();
    }

    @PreAuthorize("@ss.hasPermi('biz:schedule:update')")
    @PutMapping("/confirm/{id}")
    public AjaxResult confirm(@PathVariable Long id) {
        jdbcTemplate.update("UPDATE t_sch_appointment SET apt_status=1 WHERE apt_id=?", id);
        return success();
    }
}
