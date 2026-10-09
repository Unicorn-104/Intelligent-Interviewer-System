package com.ruoyi.web.controller.tenant;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.service.ICompanyService;
import com.ruoyi.system.domain.Company;
import java.util.*;

/**
 * 后台管理端Controller
 *
 * @author TQY
 */
@RestController
@RequestMapping("/tenant/user")
public class TenantUserController extends BaseController {

    @Autowired
    private ICompanyService companyService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /**
 * 后台管理端Controller
 *
 * @author TQY
 */
    @PreAuthorize("@ss.hasPermi('tenant:user:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Company> companies = companyService.selectCompanyList(new Company());
        List<Map<String, Object>> result = new ArrayList<>();
        
        for (Company c : companies) {
            Map<String, Object> item = new HashMap<>();
            item.put("companyId", c.getCmpId());
            item.put("companyName", c.getCmpName());
            // 从cmp_size推断套餐类型
            String size = c.getCmpSize();
            if (size != null) {
                item.put("packageType", size.contains("大型") ? "flag" : size.contains("中型") ? "pro" : "basic");
                item.put("packageTypeName", size.contains("大型") ? "旗舰版" : size.contains("中型") ? "专业版" : "基础版");
            } else {
                item.put("packageType", "basic");
                item.put("packageTypeName", "基础版");
            }
            item.put("status", c.getCmpStatus() != null && c.getCmpStatus() == 1 ? "0" : "1");
            // 从创建时间计算到期时间（1年有效期）
            String expireTime = "2026-12-31";
            if (c.getCmpCreatedAt() != null) {
                Calendar cal = Calendar.getInstance();
                cal.setTime(c.getCmpCreatedAt());
                cal.add(Calendar.YEAR, 1);
                expireTime = new java.text.SimpleDateFormat("yyyy-MM-dd").format(cal.getTime());
            }
            item.put("expireTime", expireTime);
            item.put("apiQuota", c.getApiQuota() != null ? c.getApiQuota() : 10000);
            item.put("apiUsed", c.getApiUsed() != null ? c.getApiUsed() : 0);
            
            // 从 sys_user 表查真实员工
            List<Map<String, Object>> employees = getRealEmployees(c.getCmpId());
            item.put("employeeCount", employees.size());
            item.put("employees", employees);
            result.add(item);
        }
        
        return getDataTable(result);
    }

    /**
 * 后台管理端Controller
 *
 * @author TQY
 */
    private List<Map<String, Object>> getRealEmployees(Long companyId) {
        String sql = "SELECT user_id, user_name, nick_name, phonenumber, status, create_time FROM sys_user WHERE company_id = ?";
        List<Map<String, Object>> rawList = jdbcTemplate.queryForList(sql, companyId);
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> row : rawList) {
            Map<String, Object> item = new HashMap<>();
            item.put("userId", row.get("user_id"));
            item.put("realName", row.get("nick_name"));
            item.put("userName", row.get("user_name"));
            item.put("phonenumber", row.get("phonenumber"));
            item.put("position", "员工");
            item.put("status", row.get("status"));
            item.put("entryTime", row.get("create_time"));
            result.add(item);
        }
        return result;
    }

    /**
 * 后台管理端Controller
 *
 * @author TQY
 */
    @PreAuthorize("@ss.hasPermi('tenant:user:query')")
    @GetMapping("/{companyId}")
    public AjaxResult getInfo(@PathVariable("companyId") Long companyId) {
        Map<String, Object> result = new HashMap<>();
        Company c = companyService.selectCompanyByCmpId(companyId);
        if (c != null) {
            result.put("companyId", c.getCmpId());
            result.put("companyName", c.getCmpName());
            // 从cmp_size推断套餐类型
            String size = c.getCmpSize();
            if (size != null) {
                result.put("packageType", size.contains("大型") ? "flag" : size.contains("中型") ? "pro" : "basic");
                result.put("packageTypeName", size.contains("大型") ? "旗舰版" : size.contains("中型") ? "专业版" : "基础版");
            } else {
                result.put("packageType", "basic");
                result.put("packageTypeName", "基础版");
            }
            // 从创建时间计算到期时间（1年有效期）
            String expireTime = "2026-12-31";
            if (c.getCmpCreatedAt() != null) {
                Calendar cal = Calendar.getInstance();
                cal.setTime(c.getCmpCreatedAt());
                cal.add(Calendar.YEAR, 1);
                expireTime = new java.text.SimpleDateFormat("yyyy-MM-dd").format(cal.getTime());
            }
            result.put("expireTime", expireTime);
            result.put("apiQuota", c.getApiQuota() != null ? c.getApiQuota() : 10000);
            result.put("apiUsed", c.getApiUsed() != null ? c.getApiUsed() : 0);
            result.put("employees", getRealEmployees(companyId));
        }
        return success(result);
    }
}
