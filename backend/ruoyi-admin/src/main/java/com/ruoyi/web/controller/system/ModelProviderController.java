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
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.service.IModelProviderService;

/**
 * 模型Provider配置Controller（管理员端）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/system/modelProvider")
public class ModelProviderController extends BaseController
{
    @Autowired
    private IModelProviderService modelProviderService;

    /**
     * 查询模型Provider列表
     */
    @PreAuthorize("@ss.hasPermi('system:modelProvider:list')")
    @GetMapping("/list")
    public TableDataInfo list(ModelProvider modelProvider)
    {
        startPage();
        List<ModelProvider> list = modelProviderService.selectModelProviderList(modelProvider);
        return getDataTable(list);
    }

    /**
     * 获取模型Provider详细信息
     */
    @PreAuthorize("@ss.hasPermi('system:modelProvider:query')")
    @GetMapping(value = "/{mppId}")
    public AjaxResult getInfo(@PathVariable("mppId") Long mppId)
    {
        return success(modelProviderService.selectModelProviderByMppId(mppId));
    }

    /**
     * 新增模型Provider
     */
    @PreAuthorize("@ss.hasPermi('system:modelProvider:add')")
    @Log(title = "模型Provider", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@RequestBody ModelProvider modelProvider)
    {
        return toAjax(modelProviderService.insertModelProvider(modelProvider));
    }

    /**
     * 修改模型Provider
     */
    @PreAuthorize("@ss.hasPermi('system:modelProvider:edit')")
    @Log(title = "模型Provider", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@RequestBody ModelProvider modelProvider)
    {
        return toAjax(modelProviderService.updateModelProvider(modelProvider));
    }

    /**
     * 删除模型Provider
     */
    @PreAuthorize("@ss.hasPermi('system:modelProvider:remove')")
    @Log(title = "模型Provider", businessType = BusinessType.DELETE)
    @DeleteMapping("/{mppIds}")
    public AjaxResult remove(@PathVariable Long[] mppIds)
    {
        return toAjax(1);
    }
}
