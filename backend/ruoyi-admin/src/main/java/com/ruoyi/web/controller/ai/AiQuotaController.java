package com.ruoyi.web.controller.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import java.util.*;

/**
 * 后台管理端Controller
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/quota")
public class AiQuotaController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('ai:quota:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        
        // 从 t_cmp 表查询企业配额信息
        String sql = "SELECT cmp_id, cmp_name, api_quota, api_used FROM t_cmp WHERE cmp_status = 1";
        List<Map<String, Object>> rawList = jdbcTemplate.queryForList(sql);
        
        List<Map<String, Object>> result = new ArrayList<>();
        // 计算下个月1号作为重置日期
        java.util.Calendar cal = java.util.Calendar.getInstance();
        cal.add(java.util.Calendar.MONTH, 1);
        cal.set(java.util.Calendar.DAY_OF_MONTH, 1);
        String resetDate = new java.text.SimpleDateFormat("yyyy-MM-dd").format(cal.getTime());
        
        for (Map<String, Object> row : rawList) {
            Map<String, Object> item = new HashMap<>();
            item.put("quotaId", row.get("cmp_id"));
            item.put("companyName", row.get("cmp_name"));
            item.put("monthlyQuota", row.get("api_quota"));
            item.put("used", row.get("api_used"));
            item.put("resetDate", resetDate);
            result.add(item);
        }
        
        return getDataTable(result);
    }

    /**
 * 后台管理端Controller
 *
 * @author TQY
 */
    @PreAuthorize("@ss.hasPermi('ai:quota:edit')")
    @PutMapping("/adjust")
    public AjaxResult adjust(@RequestBody Map<String, Object> data) {
        Object quotaIdObj = data.get("quotaId");
        if (quotaIdObj == null) {
            return AjaxResult.error("配额ID不能为空");
        }
        Object newQuotaObj = data.get("newQuota");
        if (newQuotaObj == null) {
            return AjaxResult.error("新配额不能为空");
        }
        Long quotaId = ((Number) quotaIdObj).longValue();
        Integer newQuota = Integer.valueOf(newQuotaObj.toString());
        if (newQuota < 0) {
            return AjaxResult.error("配额不能为负数");
        }
        int rows = jdbcTemplate.update("UPDATE t_cmp SET api_quota = ? WHERE cmp_id = ?", newQuota, quotaId);
        return toAjax(rows);
    }

    /**
 * 后台管理端Controller
 *
 * @author TQY
 */
    @PreAuthorize("@ss.hasPermi('ai:quota:query')")
    @GetMapping("/usage/{quotaId}")
    public AjaxResult usageDetail(@PathVariable("quotaId") Long quotaId) {
        // 从 t_agent_call_log 查询近30天调用记录（按企业ID过滤）
        String sql = "SELECT DATE(acl_created_at) as call_date, COUNT(*) as call_count " +
                "FROM t_agent_call_log " +
                "WHERE acl_created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) " +
                "AND acl_company_id = ? " +
                "GROUP BY DATE(acl_created_at) ORDER BY call_date";
        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql, quotaId);
        return success(list);
    }
}
