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
import com.ruoyi.system.domain.Ad;
import com.ruoyi.system.service.IAdService;

/**
 * 广告管理Controller
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ad/advert")
public class AdController extends BaseController
{
    @Autowired
    private IAdService adService;

    /**
     * 查询广告管理列表
     */
    @PreAuthorize("@ss.hasPermi('ad:advert:list')")
    @GetMapping("/list")
    public TableDataInfo list(Ad ad)
    {
        startPage();
        List<Ad> list = adService.selectAdList(ad);
        return getDataTable(list);
    }

    /**
     * 获取广告管理详细信息
     */
    @PreAuthorize("@ss.hasPermi('ad:advert:query')")
    @GetMapping(value = "/{advertId}")
    public AjaxResult getInfo(@PathVariable("advertId") Long advertId)
    {
        return success(adService.selectAdByAdvertId(advertId));
    }

    /**
     * 新增广告管理
     */
    @PreAuthorize("@ss.hasPermi('ad:advert:add')")
    @Log(title = "广告管理", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult add(@Validated @RequestBody Ad ad)
    {
        return toAjax(adService.insertAd(ad));
    }

    /**
     * 修改广告管理
     */
    @PreAuthorize("@ss.hasPermi('ad:advert:edit')")
    @Log(title = "广告管理", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult edit(@Validated @RequestBody Ad ad)
    {
        return toAjax(adService.updateAd(ad));
    }

    /**
     * 删除广告管理
     */
    @PreAuthorize("@ss.hasPermi('ad:advert:remove')")
    @Log(title = "广告管理", businessType = BusinessType.DELETE)
    @DeleteMapping("/{advertIds}")
    public AjaxResult remove(@PathVariable Long[] advertIds)
    {
        return toAjax(adService.deleteAdByAdvertIds(advertIds));
    }

    /**
     * 修改广告状态
     */
    @PreAuthorize("@ss.hasPermi('ad:advert:edit')")
    @Log(title = "广告管理", businessType = BusinessType.UPDATE)
    @PutMapping("/changeStatus")
    public AjaxResult changeStatus(@RequestBody Ad ad)
    {
        return toAjax(adService.updateAdStatus(ad));
    }

    /**
     * 获取广告统计数据
     */
    @PreAuthorize("@ss.hasPermi('ad:advert:query')")
    @GetMapping("/stats/{advertId}")
    public AjaxResult stats(@PathVariable("advertId") Long advertId)
    {
        Ad ad = adService.selectAdByAdvertId(advertId);
        return success(ad);
    }
}
