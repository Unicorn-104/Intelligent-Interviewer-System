package com.ruoyi.web.controller.system;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
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

    @Autowired
    private JdbcTemplate jdbcTemplate;

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

    /**
     * 确认告警
     */
    @PutMapping("/confirm/{salId}")
    public AjaxResult confirm(@PathVariable("salId") Long salId)
    {
        int rows = jdbcTemplate.update(
            "UPDATE t_sys_alert SET sal_status = 1, sal_handled_at = NOW() WHERE sal_id = ?",
            salId
        );
        return toAjax(rows);
    }

    /**
     * 忽略告警
     */
    @PutMapping("/ignore/{salId}")
    public AjaxResult ignore(@PathVariable("salId") Long salId)
    {
        int rows = jdbcTemplate.update(
            "UPDATE t_sys_alert SET sal_status = 2, sal_handled_at = NOW() WHERE sal_id = ?",
            salId
        );
        return toAjax(rows);
    }

    /**
     * 解决告警
     */
    @PutMapping("/resolve/{salId}")
    public AjaxResult resolve(@PathVariable("salId") Long salId)
    {
        int rows = jdbcTemplate.update(
            "UPDATE t_sys_alert SET sal_status = 3, sal_handled_at = NOW() WHERE sal_id = ?",
            salId
        );
        return toAjax(rows);
    }
}
