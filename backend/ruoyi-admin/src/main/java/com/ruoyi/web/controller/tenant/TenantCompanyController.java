package com.ruoyi.web.controller.tenant;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.service.ICompanyService;
import com.ruoyi.system.domain.Company;
import java.util.*;

/**
 * 企业管理（对齐前端 /tenant/company 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/tenant/company")
public class TenantCompanyController extends BaseController {

    @Autowired
    private ICompanyService companyService;

    @PreAuthorize("@ss.hasPermi('tenant:company:list')")
    @GetMapping("/list")
    public TableDataInfo list(
            @RequestParam(required = false) String companyName,
            @RequestParam(required = false) Integer verifyStatus,
            @RequestParam(required = false) Integer pageNum,
            @RequestParam(required = false) Integer pageSize) {
        startPage();
        Company query = new Company();
        query.setCmpName(companyName);
        query.setCmpVerifyStatus(verifyStatus);
        List<Company> list = companyService.selectCompanyList(query);
        List<Map<String, Object>> result = new ArrayList<>();
        for (Company c : list) {
            Map<String, Object> item = new HashMap<>();
            item.put("companyId", c.getCmpId());
            item.put("companyName", c.getCmpName());
            item.put("creditCode", c.getCmpCreditCode());
            item.put("industry", c.getCmpIndustry());
            item.put("size", c.getCmpSize());
            item.put("city", c.getCmpCity());
            item.put("address", c.getCmpAddress());
            item.put("website", c.getCmpWebsite());
            item.put("intro", c.getCmpIntro());
            item.put("verifyStatus", c.getCmpVerifyStatus() != null ? c.getCmpVerifyStatus() : 0);
            item.put("createTime", c.getCmpCreatedAt());
            result.add(item);
        }
        return getDataTable(result);
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:query')")
    @GetMapping("/{companyId}")
    public AjaxResult getInfo(@PathVariable("companyId") Long companyId) {
        Company c = companyService.selectCompanyByCmpId(companyId);
        if (c == null) {
            return error("企业不存在");
        }
        Map<String, Object> item = new HashMap<>();
        item.put("companyId", c.getCmpId());
        item.put("companyName", c.getCmpName());
        item.put("creditCode", c.getCmpCreditCode());
        item.put("industry", c.getCmpIndustry());
        item.put("size", c.getCmpSize());
        item.put("city", c.getCmpCity());
        item.put("address", c.getCmpAddress());
        item.put("website", c.getCmpWebsite());
        item.put("intro", c.getCmpIntro());
        item.put("verifyStatus", c.getCmpVerifyStatus() != null ? c.getCmpVerifyStatus() : 0);
        item.put("createTime", c.getCmpCreatedAt());
        return success(item);
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> data) {
        String companyName = (String) data.get("companyName");
        if (companyName == null || companyName.trim().isEmpty()) {
            return AjaxResult.error("企业名称不能为空");
        }
        Company company = new Company();
        company.setCmpName(companyName);
        company.setCmpStatus(1);
        return toAjax(companyService.insertCompany(company));
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> data) {
        Object companyIdObj = data.get("companyId");
        if (companyIdObj == null) {
            return AjaxResult.error("企业ID不能为空");
        }
        Company company = new Company();
        company.setCmpId(Long.valueOf(companyIdObj.toString()));
        company.setCmpName((String) data.get("companyName"));
        return toAjax(companyService.updateCompany(company));
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:remove')")
    @DeleteMapping("/{companyIds}")
    public AjaxResult remove(@PathVariable Long[] companyIds) {
        for (Long id : companyIds) {
            companyService.deleteCompanyByCmpId(id);
        }
        return success();
    }

    @PreAuthorize("@ss.hasPermi('tenant:company:edit')")
    @PutMapping("/changeStatus")
    public AjaxResult changeStatus(@RequestBody Map<String, Object> data) {
        Object companyIdObj = data.get("companyId");
        if (companyIdObj == null) {
            return AjaxResult.error("企业ID不能为空");
        }
        Object statusObj = data.get("status");
        if (statusObj == null) {
            return AjaxResult.error("状态不能为空");
        }
        Company company = new Company();
        company.setCmpId(((Number) companyIdObj).longValue());
        company.setCmpStatus(Integer.valueOf(statusObj.toString()));
        return toAjax(companyService.updateCompany(company));
    }

    /**
     * 企业审核
     */
    @PreAuthorize("@ss.hasPermi('tenant:company:audit')")
    @PutMapping("/audit")
    public AjaxResult audit(@RequestBody Map<String, Object> data) {
        Object companyIdObj = data.get("companyId");
        if (companyIdObj == null) {
            return AjaxResult.error("企业ID不能为空");
        }
        Object statusObj = data.get("status");
        if (statusObj == null) {
            return AjaxResult.error("审核状态不能为空");
        }
        Long companyId = Long.valueOf(companyIdObj.toString());
        Integer status = Integer.valueOf(statusObj.toString()); // 1通过 2拒绝
        String rejectReason = data.get("rejectReason") != null ? data.get("rejectReason").toString() : "";
        return toAjax(companyService.verifyCompany(companyId, status, getUserId(), rejectReason));
    }
}
