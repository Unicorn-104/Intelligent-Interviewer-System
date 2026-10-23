package com.ruoyi.web.controller.tenant;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.system.service.ICompanyService;
import com.ruoyi.system.domain.Company;
import java.text.SimpleDateFormat;
import java.util.*;

/**
 * 企业用户（租户）管理Controller
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
     * 企业租户列表（含员工、套餐、到期、API用量）
     */
    @PreAuthorize("@ss.hasPermi('tenant:user:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Company> companies = companyService.selectCompanyList(new Company());
        List<Map<String, Object>> result = new ArrayList<>();

        for (Company c : companies) {
            result.add(buildCompanyItem(c));
        }
        return getDataTable(result);
    }

    /**
     * 单个企业租户详情
     */
    @PreAuthorize("@ss.hasPermi('tenant:user:list')")
    @GetMapping("/{companyId}")
    public AjaxResult getInfo(@PathVariable("companyId") Long companyId) {
        Company c = companyService.selectCompanyByCmpId(companyId);
        if (c == null) {
            return AjaxResult.error("企业不存在");
        }
        return success(buildCompanyItem(c));
    }

    /**
     * 启用/停用企业员工（改 sys_user.status：0正常 1停用）
     */
    @PreAuthorize("@ss.hasPermi('tenant:user:list')")
    @PutMapping("/employee/status")
    public AjaxResult employeeStatus(@RequestBody Map<String, Object> data) {
        Long userId = toLong(data.get("userId"));
        Long companyId = toLong(data.get("companyId"));
        String status = data.get("status") == null ? "1" : data.get("status").toString();
        if (userId == null || companyId == null) {
            return AjaxResult.error("参数缺失");
        }
        if (!ownsEmployee(userId, companyId)) {
            return AjaxResult.error("该员工不属于此企业");
        }
        int rows = jdbcTemplate.update("UPDATE sys_user SET status = ? WHERE user_id = ?", status, userId);
        return rows > 0 ? success("操作成功") : AjaxResult.error("操作失败");
    }

    /**
     * 重置企业员工密码（BCrypt加密落库）
     */
    @PreAuthorize("@ss.hasPermi('tenant:user:list')")
    @PutMapping("/employee/resetPwd")
    public AjaxResult resetPwd(@RequestBody Map<String, Object> data) {
        Long userId = toLong(data.get("userId"));
        Long companyId = toLong(data.get("companyId"));
        Object pwd = data.get("password");
        if (userId == null || companyId == null || pwd == null || pwd.toString().trim().isEmpty()) {
            return AjaxResult.error("参数缺失");
        }
        if (!ownsEmployee(userId, companyId)) {
            return AjaxResult.error("该员工不属于此企业");
        }
        String encoded = SecurityUtils.encryptPassword(pwd.toString().trim());
        int rows = jdbcTemplate.update("UPDATE sys_user SET password = ? WHERE user_id = ?", encoded, userId);
        return rows > 0 ? success("密码已重置") : AjaxResult.error("操作失败");
    }

    /**
     * 续费/改套餐：更新套餐类型、到期日期、API配额
     */
    @PreAuthorize("@ss.hasPermi('tenant:user:list')")
    @PutMapping("/subscription")
    public AjaxResult subscription(@RequestBody Map<String, Object> data) {
        Long companyId = toLong(data.get("companyId"));
        if (companyId == null) {
            return AjaxResult.error("企业ID不能为空");
        }
        Company c = companyService.selectCompanyByCmpId(companyId);
        if (c == null) {
            return AjaxResult.error("企业不存在");
        }
        if (data.get("packageType") != null) {
            c.setPackageType(data.get("packageType").toString());
        }
        if (data.get("apiQuota") != null) {
            c.setApiQuota(Integer.valueOf(data.get("apiQuota").toString()));
        }
        if (data.get("contactName") != null) {
            c.setContactName(data.get("contactName").toString());
        }
        if (data.get("contactPhone") != null) {
            c.setContactPhone(data.get("contactPhone").toString());
        }
        if (data.get("expireDate") != null && !data.get("expireDate").toString().isEmpty()) {
            try {
                c.setExpireDate(new SimpleDateFormat("yyyy-MM-dd").parse(data.get("expireDate").toString()));
            } catch (Exception e) {
                return AjaxResult.error("到期日期格式应为 yyyy-MM-dd");
            }
        }
        return companyService.updateCompany(c) > 0 ? success("套餐已更新") : AjaxResult.error("操作失败");
    }

    /** 组装企业展示对象：套餐优先读 package_type，到期优先读 expire_date，缺失再兜底推算 */
    private Map<String, Object> buildCompanyItem(Company c) {
        Map<String, Object> item = new HashMap<>();
        item.put("companyId", c.getCmpId());
        item.put("companyName", c.getCmpName());

        String[] pkg = resolvePackage(c);
        item.put("packageType", pkg[0]);
        item.put("packageTypeName", pkg[1]);

        item.put("status", c.getCmpStatus() != null && c.getCmpStatus() == 1 ? "0" : "1");
        item.put("expireTime", resolveExpire(c));
        item.put("apiQuota", c.getApiQuota() != null ? c.getApiQuota() : 10000);
        item.put("apiUsed", c.getApiUsed() != null ? c.getApiUsed() : 0);
        item.put("contactName", c.getContactName());
        item.put("contactPhone", c.getContactPhone());

        List<Map<String, Object>> employees = getRealEmployees(c.getCmpId());
        item.put("employeeCount", employees.size());
        item.put("employees", employees);
        return item;
    }

    /** 套餐：优先 package_type 列，否则按企业规模推断 */
    private String[] resolvePackage(Company c) {
        String type = c.getPackageType();
        if (type != null && !type.isEmpty()) {
            return new String[]{type, packageName(type)};
        }
        String size = c.getCmpSize();
        if (size != null && size.contains("大型")) {
            return new String[]{"flag", "旗舰版"};
        }
        if (size != null && size.contains("中型")) {
            return new String[]{"pro", "专业版"};
        }
        return new String[]{"basic", "基础版"};
    }

    private String packageName(String type) {
        if ("flag".equals(type)) return "旗舰版";
        if ("pro".equals(type)) return "专业版";
        return "基础版";
    }

    /** 到期：优先 expire_date，否则按创建时间+1年兜底 */
    private String resolveExpire(Company c) {
        if (c.getExpireDate() != null) {
            return new SimpleDateFormat("yyyy-MM-dd").format(c.getExpireDate());
        }
        if (c.getCmpCreatedAt() != null) {
            Calendar cal = Calendar.getInstance();
            cal.setTime(c.getCmpCreatedAt());
            cal.add(Calendar.YEAR, 1);
            return new SimpleDateFormat("yyyy-MM-dd").format(cal.getTime());
        }
        return "";
    }

    private List<Map<String, Object>> getRealEmployees(Long companyId) {
        String sql = "SELECT user_id, user_name, nick_name, phonenumber, status, create_time FROM sys_user WHERE company_id = ? AND del_flag = '0'";
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

    /** 校验员工归属该企业，防止越权操作 */
    private boolean ownsEmployee(Long userId, Long companyId) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                "SELECT company_id FROM sys_user WHERE user_id = ? AND del_flag = '0'", userId);
        return !rows.isEmpty() && companyId.equals(rows.get(0).get("company_id"));
    }

    private Long toLong(Object o) {
        if (o == null) return null;
        try {
            return Long.valueOf(o.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
