package com.ruoyi.web.controller.system;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.domain.SysAlert;
import com.ruoyi.system.service.ISysAlertService;

/**
 * 告警记录Controller（管理员端）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/system/sysAlert")
public class SysAlertController extends BaseController
{
    @Autowired
    private ISysAlertService sysAlertService;

    /**
     * 查询告警记录列表
     */
    @PreAuthorize("@ss.hasPermi('system:sysAlert:list')")
    @GetMapping("/list")
    public TableDataInfo list(SysAlert sysAlert)
    {
        startPage();
        List<SysAlert> list = sysAlertService.selectSysAlertList(sysAlert);
        return getDataTable(list);
    }

    /**
     * 获取告警记录详细信息
     */
    @PreAuthorize("@ss.hasPermi('system:sysAlert:query')")
    @GetMapping(value = "/{salId}")
    public AjaxResult getInfo(@PathVariable("salId") Long salId)
    {
        return success(sysAlertService.selectSysAlertBySalId(salId));
    }
}
