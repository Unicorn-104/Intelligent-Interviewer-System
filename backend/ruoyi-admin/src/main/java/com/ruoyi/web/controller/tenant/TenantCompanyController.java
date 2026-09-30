package com.ruoyi.web.controller.tenant;

import org.springframework.beans.factory.annotation.Autowired;
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

    @GetMapping("/{companyId}")
    public AjaxResult getInfo(@PathVariable("companyId") Long companyId) {
        return success(companyService.selectCompanyByCmpId(companyId));
    }

    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> data) {
        Company company = new Company();
        company.setCmpName((String) data.get("companyName"));
        company.setCmpStatus(1);
        return toAjax(companyService.insertCompany(company));
    }

    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> data) {
        Company company = new Company();
        company.setCmpId(Long.valueOf(data.get("companyId").toString()));
        company.setCmpName((String) data.get("companyName"));
        return toAjax(companyService.updateCompany(company));
    }

    @DeleteMapping("/{companyIds}")
    public AjaxResult remove(@PathVariable Long[] companyIds) {
        for (Long id : companyIds) {
            companyService.deleteCompanyByCmpId(id);
        }
        return success();
    }

    @PutMapping("/changeStatus")
    public AjaxResult changeStatus(@RequestBody Map<String, Object> data) {
        return success();
    }

    /**
     * 企业审核
     */
    @PutMapping("/audit")
    public AjaxResult audit(@RequestBody Map<String, Object> data) {
        Long companyId = Long.valueOf(data.get("companyId").toString());
        Integer status = Integer.valueOf(data.get("status").toString()); // 1通过 2拒绝
        String rejectReason = data.get("rejectReason") != null ? data.get("rejectReason").toString() : "";
        return toAjax(companyService.verifyCompany(companyId, status, getUserId(), rejectReason));
    }
}
