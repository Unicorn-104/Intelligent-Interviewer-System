package com.ruoyi.web.controller.system;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.domain.Company;
import com.ruoyi.system.service.ICompanyService;

/**
 * 企业信息Controller（管理员端审核）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/system/company")
public class CompanyController extends BaseController
{
    @Autowired
    private ICompanyService companyService;

    /**
     * 查询企业列表
     */
    @PreAuthorize("@ss.hasPermi('system:company:list')")
    @GetMapping("/list")
    public TableDataInfo list(Company company)
    {
        startPage();
        List<Company> list = companyService.selectCompanyList(company);
        return getDataTable(list);
    }

    /**
     * 获取企业详细信息
     */
    @PreAuthorize("@ss.hasPermi('system:company:query')")
    @GetMapping(value = "/{cmpId}")
    public AjaxResult getInfo(@PathVariable("cmpId") Long cmpId)
    {
        return success(companyService.selectCompanyByCmpId(cmpId));
    }

    /**
     * 审核企业：通过或拒绝
     */
    @PreAuthorize("@ss.hasPermi('system:company:verify')")
    @Log(title = "企业审核", businessType = BusinessType.UPDATE)
    @PutMapping("/verify/{cmpId}/{verifyStatus}")
    public AjaxResult verify(@PathVariable("cmpId") Long cmpId,
                             @PathVariable("verifyStatus") Integer verifyStatus,
                             @RequestBody(required = false) String rejectReason)
    {
        return toAjax(companyService.verifyCompany(cmpId, verifyStatus, getUserId(), rejectReason));
    }

    /**
     * 启停用企业
     */
    @PreAuthorize("@ss.hasPermi('system:company:changeStatus')")
    @Log(title = "企业状态", businessType = BusinessType.UPDATE)
    @PutMapping("/changeStatus/{cmpId}/{status}")
    public AjaxResult changeStatus(@PathVariable("cmpId") Long cmpId,
                                    @PathVariable("status") Integer status)
    {
        return toAjax(companyService.changeStatus(cmpId, status));
    }

    /**
     * 新增企业
     */
    @PreAuthorize("@ss.hasPermi('system:company:add')")
    @Log(title = "企业信息", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody Company company)
    {
        return toAjax(companyService.insertCompany(company));
    }

    /**
     * 修改企业
     */
    @PreAuthorize("@ss.hasPermi('system:company:edit')")
    @Log(title = "企业信息", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody Company company)
    {
        return toAjax(companyService.updateCompany(company));
    }

    /**
     * 删除企业
     */
    @PreAuthorize("@ss.hasPermi('system:company:remove')")
    @Log(title = "企业信息", businessType = BusinessType.DELETE)
    @DeleteMapping("/{cmpIds}")
    public AjaxResult remove(@PathVariable Long[] cmpIds)
    {
        return toAjax(1);
    }
}
