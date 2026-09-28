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
import com.ruoyi.system.domain.PromptVersion;
import com.ruoyi.system.service.IPromptVersionService;

/**
 * Prompt版本管理Controller（管理员端）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/system/promptVersion")
public class PromptVersionController extends BaseController
{
    @Autowired
    private IPromptVersionService promptVersionService;

    /**
     * 查询Prompt版本列表
     */
    @PreAuthorize("@ss.hasPermi('system:promptVersion:list')")
    @GetMapping("/list")
    public TableDataInfo list(PromptVersion promptVersion)
    {
        startPage();
        List<PromptVersion> list = promptVersionService.selectPromptVersionList(promptVersion);
        return getDataTable(list);
    }

    /**
     * 获取Prompt版本详细信息
     */
    @PreAuthorize("@ss.hasPermi('system:promptVersion:query')")
    @GetMapping(value = "/{pmvId}")
    public AjaxResult getInfo(@PathVariable("pmvId") Long pmvId)
    {
        return success(promptVersionService.selectPromptVersionByPmvId(pmvId));
    }

    /**
     * 新增Prompt版本
     */
    @PreAuthorize("@ss.hasPermi('system:promptVersion:add')")
    @Log(title = "Prompt版本", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody PromptVersion promptVersion)
    {
        return toAjax(promptVersionService.insertPromptVersion(promptVersion));
    }

    /**
     * 修改Prompt版本
     */
    @PreAuthorize("@ss.hasPermi('system:promptVersion:edit')")
    @Log(title = "Prompt版本", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody PromptVersion promptVersion)
    {
        return toAjax(promptVersionService.updatePromptVersion(promptVersion));
    }

    /**
     * 删除Prompt版本
     */
    @PreAuthorize("@ss.hasPermi('system:promptVersion:remove')")
    @Log(title = "Prompt版本", businessType = BusinessType.DELETE)
    @DeleteMapping("/{pmvIds}")
    public AjaxResult remove(@PathVariable Long[] pmvIds)
    {
        return toAjax(1);
    }
}
