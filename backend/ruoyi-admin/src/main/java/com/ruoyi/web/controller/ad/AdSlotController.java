package com.ruoyi.web.controller.ad;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
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
import com.ruoyi.system.domain.AdSlot;
import com.ruoyi.system.service.IAdSlotService;

/**
 * 广告位管理Controller
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ad/slot")
public class AdSlotController extends BaseController
{
    @Autowired
    private IAdSlotService adSlotService;

    /**
     * 查询广告位管理列表
     */
    @PreAuthorize("@ss.hasPermi('ad:slot:list')")
    @GetMapping("/list")
    public TableDataInfo list(AdSlot adSlot)
    {
        startPage();
        List<AdSlot> list = adSlotService.selectAdSlotList(adSlot);
        return getDataTable(list);
    }

    /**
     * 获取广告位管理详细信息
     */
    @PreAuthorize("@ss.hasPermi('ad:slot:query')")
    @GetMapping(value = "/{slotCode}")
    public AjaxResult getInfo(@PathVariable("slotCode") String slotCode)
    {
        return success(adSlotService.selectAdSlotBySlotCode(slotCode));
    }

    /**
     * 新增广告位管理
     */
    @PreAuthorize("@ss.hasPermi('ad:slot:add')")
    @Log(title = "广告位管理", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@Validated @RequestBody AdSlot adSlot)
    {
        return toAjax(adSlotService.insertAdSlot(adSlot));
    }

    /**
     * 修改广告位管理
     */
    @PreAuthorize("@ss.hasPermi('ad:slot:edit')")
    @Log(title = "广告位管理", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@Validated @RequestBody AdSlot adSlot)
    {
        return toAjax(adSlotService.updateAdSlot(adSlot));
    }

    /**
     * 删除广告位管理
     */
    @PreAuthorize("@ss.hasPermi('ad:slot:remove')")
    @Log(title = "广告位管理", businessType = BusinessType.DELETE)
    @DeleteMapping("/{slotCodes}")
    public AjaxResult remove(@PathVariable String[] slotCodes)
    {
        return toAjax(adSlotService.deleteAdSlotBySlotCodes(slotCodes));
    }

    /**
     * 修改广告位状态
     */
    @PreAuthorize("@ss.hasPermi('ad:slot:edit')")
    @Log(title = "广告位管理", businessType = BusinessType.UPDATE)
    @PutMapping("/changeStatus")
    public AjaxResult changeStatus(@RequestBody AdSlot adSlot)
    {
        return toAjax(adSlotService.updateAdSlotStatus(adSlot));
    }
}
