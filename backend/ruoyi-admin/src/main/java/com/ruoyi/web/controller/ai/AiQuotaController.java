package com.ruoyi.web.controller.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.page.TableDataInfo;
import java.util.*;

/**
 * AI配额管理（对齐前端 /ai/quota 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/quota")
public class AiQuotaController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        
        // 从 t_cmp 表查询企业配额信息
        String sql = "SELECT cmp_id, cmp_name, api_quota, api_used FROM t_cmp WHERE cmp_status = 1";
        List<Map<String, Object>> rawList = jdbcTemplate.queryForList(sql);
        
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> row : rawList) {
            Map<String, Object> item = new HashMap<>();
            item.put("companyName", row.get("cmp_name"));
            item.put("modelName", "GPT-4");
            item.put("monthlyQuota", row.get("api_quota"));
            item.put("used", row.get("api_used"));
            item.put("resetDate", "2026-10-01");
            result.add(item);
        }
        
        return getDataTable(result);
    }
}
