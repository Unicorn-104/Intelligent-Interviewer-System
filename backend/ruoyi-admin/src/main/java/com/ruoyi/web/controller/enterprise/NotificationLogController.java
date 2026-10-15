package com.ruoyi.web.controller.enterprise;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.INotificationLogService;

/**
 * 企业端 - 通知发送日志与统计
 *
 * <p>依据《业务功能分析》UC-16（全流程状态通知与模板化管理）E2：
 * HR 按候选人、场景、时间范围检索通知发送记录，
 * 查看各渠道送达率、打开率（邮件）、点击率（链接）等统计指标。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/notification")
public class NotificationLogController extends BaseController
{
    @Autowired
    private INotificationLogService notificationLogService;

    /**
     * UC-16 E2：发送日志检索（按候选人/场景/时间范围）
     */
    @GetMapping("/logs")
    public TableDataInfo logs(@RequestParam(required = false) String candidate,
            @RequestParam(required = false) String scene,
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(notificationLogService.listLogs(getUserId(), candidate, scene, from, to, pageNum, pageSize));
    }

    /**
     * UC-16 E2：送达率/打开率/点击率统计
     */
    @GetMapping("/stats")
    public AjaxResult stats()
    {
        return success(notificationLogService.getStats(getUserId()));
    }
}
