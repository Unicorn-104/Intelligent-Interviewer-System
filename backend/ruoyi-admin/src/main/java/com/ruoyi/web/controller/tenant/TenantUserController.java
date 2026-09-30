package com.ruoyi.web.controller.tenant;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.service.ICompanyService;
import com.ruoyi.system.domain.Company;
import java.util.*;

/**
 * 企业用户管理（显示企业订阅和员工）
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
     * 查询企业列表（带订阅信息和员工数）
     */
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Company> companies = companyService.selectCompanyList(new Company());
        List<Map<String, Object>> result = new ArrayList<>();
        
        for (Company c : companies) {
            Map<String, Object> item = new HashMap<>();
            item.put("companyId", c.getCmpId());
            item.put("companyName", c.getCmpName());
            item.put("packageType", "pro");
            item.put("packageTypeName", "专业版");
            item.put("status", c.getCmpStatus() != null && c.getCmpStatus() == 1 ? "0" : "1");
            item.put("expireTime", "2026-12-31");
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
     * 从 sys_user 表查真实员工
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
            item.put("position", "HR");
            item.put("status", row.get("status"));
            item.put("entryTime", row.get("create_time"));
            result.add(item);
        }
        return result;
    }

    /**
     * 获取企业详情
     */
    @GetMapping("/{companyId}")
    public AjaxResult getInfo(@PathVariable("companyId") Long companyId) {
        Map<String, Object> result = new HashMap<>();
        Company c = companyService.selectCompanyByCmpId(companyId);
        if (c != null) {
            result.put("companyId", c.getCmpId());
            result.put("companyName", c.getCmpName());
            result.put("packageType", "pro");
            result.put("packageTypeName", "专业版");
            result.put("expireTime", "2026-12-31");
            result.put("apiQuota", c.getApiQuota() != null ? c.getApiQuota() : 10000);
            result.put("apiUsed", c.getApiUsed() != null ? c.getApiUsed() : 0);
            result.put("employees", getRealEmployees(companyId));
        }
        return success(result);
    }
}
