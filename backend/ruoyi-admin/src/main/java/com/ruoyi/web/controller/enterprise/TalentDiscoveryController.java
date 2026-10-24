package com.ruoyi.web.controller.enterprise;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import com.ruoyi.enterprise.service.TalentDiscoveryService;

/** 人才发现与企业岗位候选人管理使用不同接口，避免混用身份与业务数据。 */
@RestController
@RequestMapping("/enterprise/talent-discovery")
public class TalentDiscoveryController extends BaseController
{
    @Autowired private TalentDiscoveryService discoveryService;
    @GetMapping
    public TableDataInfo list(@RequestParam(required=false) String keyword,
            @RequestParam(required=false) String direction, @RequestParam(required=false) Integer currentStatus,
            @RequestParam(defaultValue="1") Integer pageNum, @RequestParam(defaultValue="20") Integer pageSize,
            TalentSearchCriteria criteria)
    {
        return getDataTable(discoveryService.list(getUserId(), keyword, direction, currentStatus, pageNum, pageSize, criteria));
    }
    @GetMapping("/options")
    public AjaxResult options() { return success(discoveryService.options(getUserId())); }
    @GetMapping("/{userId}")
    public AjaxResult detail(@PathVariable Long userId) { return success(discoveryService.detail(getUserId(), userId)); }
}
