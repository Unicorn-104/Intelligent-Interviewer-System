package com.ruoyi.web.controller.system;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.IDataManageService;
import com.ruoyi.system.service.IEnterpriseSettingsService;

/**
 * 企业数据管理（导出/备份/清理）
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/system")
public class DataManageController extends BaseController
{
    @Autowired
    private IDataManageService dataManageService;

    @Autowired
    private IEnterpriseSettingsService settingsService;

    private Long companyId()
    {
        return settingsService.resolveCompanyId(getUserId());
    }

    /** 导出列表 */
    @PreAuthorize("@ss.hasPermi('system:data:list')")
    @GetMapping("/data/exportList")
    public AjaxResult exportList()
    {
        return success(new java.util.ArrayList<>());
    }

    /** 导出 */
    @PreAuthorize("@ss.hasPermi('system:data:export')")
    @GetMapping("/data/export/{id}")
    public AjaxResult exportById(@PathVariable Long id)
    {
        return success();
    }

    /** 删除导出 */
    @PreAuthorize("@ss.hasPermi('system:data:remove')")
    @DeleteMapping("/data/{id}")
    public AjaxResult removeData(@PathVariable Long id)
    {
        return success();
    }

    /** 导出本公司候选人 CSV */
    @PostMapping("/enterprise/data/export")
    public AjaxResult export()
    {
        return success(dataManageService.exportResumes(companyId()));
    }

    /** 立即备份 */
    @PostMapping("/enterprise/data/backup")
    public AjaxResult backup()
    {
        return success(dataManageService.backup(companyId()));
    }

    /** 数据概览：最近备份时间 + 可清理候选人数 */
    @GetMapping("/enterprise/data/overview")
    public AjaxResult overview()
    {
        AjaxResult ajax = AjaxResult.success();
        ajax.put("lastBackup", dataManageService.lastBackupTime(companyId()));
        ajax.put("cleanupCount", dataManageService.cleanupPreview(companyId(), 2).size());
        return ajax;
    }

    /** 清理预览 */
    @GetMapping("/enterprise/data/cleanup")
    public AjaxResult cleanupPreview()
    {
        return success(dataManageService.cleanupPreview(companyId(), 2));
    }

    /** 执行清理 */
    @PostMapping("/enterprise/data/cleanup")
    public AjaxResult cleanupExecute(@RequestBody Map<String, List<Long>> body)
    {
        int deleted = dataManageService.cleanupExecute(companyId(), body.get("talIds"));
        AjaxResult ajax = AjaxResult.success();
        ajax.put("deleted", deleted);
        return ajax;
    }
}
