package com.ruoyi.web.controller.biz;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.page.TableDataInfo;

/**
 * 平台运营 - AI分析记录 Controller
 */
@RestController
@RequestMapping("/biz/ai-analysis")
public class BizAiAnalysisController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('biz:aiAnalysis:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT a.asr_candidate_id, a.asr_resume_id, a.asr_report, a.asr_updated_at, " +
            "v.candidate_name AS tal_name, p.pos_title, c.cmp_name " +
            "FROM t_ai_candidate_analysis a " +
            "LEFT JOIN v_candidate_overview v ON a.asr_candidate_id = v.tal_id " +
            "LEFT JOIN t_pos p ON a.asr_position_id = p.pos_id " +
            "LEFT JOIN t_cmp c ON p.pos_company_id = c.cmp_id " +
            "ORDER BY a.asr_updated_at DESC");
        return getDataTable(list);
    }
}
