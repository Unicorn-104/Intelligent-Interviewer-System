package com.ruoyi.web.controller.system;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.domain.SysHealth;
import com.ruoyi.system.service.ISysHealthService;

/**
 * 服务健康监控Controller（管理员端）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/system/sysHealth")
public class SysHealthController extends BaseController
{
    @Autowired
    private ISysHealthService sysHealthService;

    /**
     * 查询服务健康列表
     */
    @PreAuthorize("@ss.hasPermi('system:sysHealth:list')")
    @GetMapping("/list")
    public TableDataInfo list(SysHealth sysHealth)
    {
        startPage();
        List<SysHealth> list = sysHealthService.selectSysHealthList(sysHealth);
        return getDataTable(list);
    }
}
