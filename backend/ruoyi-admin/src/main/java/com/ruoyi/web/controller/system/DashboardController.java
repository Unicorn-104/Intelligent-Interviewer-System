package com.ruoyi.web.controller.system;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.IDashboardService;

/**
 * 招聘总览（企业端首页）
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/system/dashboard")
public class DashboardController extends BaseController
{
    @Autowired
    private IDashboardService dashboardService;

    /**
     * 当前用户所属公司的招聘总览数据
     */
    @GetMapping("/overview")
    public AjaxResult overview()
    {
        return success(dashboardService.getOverview(getUserId()));
    }
}
