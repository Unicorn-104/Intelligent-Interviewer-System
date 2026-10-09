package com.ruoyi.web.controller.tenant;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import java.util.*;

/**
 * 企业套餐管理
 *
 * @author TQY
 */
@RestController
@RequestMapping("/tenant/package")
public class TenantPackageController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('tenant:package:list')")
    @GetMapping("/list")
    public TableDataInfo list() {
        startPage();
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT pkg_id as packageId, pkg_name as packageName, pkg_type as packageType, " +
            "api_quota as apiQuota, max_companies as maxCompanies, max_users as maxUsers, " +
            "price, pkg_status as status, description, create_time as createTime " +
            "FROM t_tenant_package ORDER BY price ASC"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('tenant:package:query')")
    @GetMapping("/{packageId}")
    public AjaxResult getInfo(@PathVariable("packageId") Long packageId) {
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT pkg_id, pkg_name, pkg_type, api_quota, max_companies, max_users, price, pkg_status, description, create_by, create_time, update_by, update_time FROM t_tenant_package WHERE pkg_id = ?", packageId
        );
        if (list.isEmpty()) {
            return error("套餐不存在");
        }
        return success(list.get(0));
    }

    @PreAuthorize("@ss.hasPermi('tenant:package:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> data) {
        String packageName = (String) data.get("packageName");
        if (packageName == null || packageName.trim().isEmpty()) {
            return AjaxResult.error("套餐名称不能为空");
        }
        jdbcTemplate.update(
            "INSERT INTO t_tenant_package (pkg_name, pkg_type, api_quota, max_companies, max_users, price, pkg_status, description, create_by) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            packageName, data.get("packageType"), data.get("apiQuota"),
            data.get("maxCompanies"), data.get("maxUsers"), data.get("price"),
            "0", data.get("description"), getUsername()
        );
        return success();
    }

    @PreAuthorize("@ss.hasPermi('tenant:package:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> data) {
        Object packageIdObj = data.get("packageId");
        if (packageIdObj == null) {
            return AjaxResult.error("套餐ID不能为空");
        }
        jdbcTemplate.update(
            "UPDATE t_tenant_package SET pkg_name = ?, pkg_type = ?, api_quota = ?, " +
            "max_companies = ?, max_users = ?, price = ?, description = ?, update_by = ? WHERE pkg_id = ?",
            data.get("packageName"), data.get("packageType"), data.get("apiQuota"),
            data.get("maxCompanies"), data.get("maxUsers"), data.get("price"),
            data.get("description"), getUsername(), packageIdObj
        );
        return success();
    }

    @PreAuthorize("@ss.hasPermi('tenant:package:remove')")
    @DeleteMapping("/{packageIds}")
    public AjaxResult remove(@PathVariable Long[] packageIds) {
        for (Long id : packageIds) {
            jdbcTemplate.update("DELETE FROM t_tenant_package WHERE pkg_id = ?", id);
        }
        return success();
    }
}
