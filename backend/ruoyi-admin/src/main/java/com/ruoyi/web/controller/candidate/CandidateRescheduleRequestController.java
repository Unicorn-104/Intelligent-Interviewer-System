package com.ruoyi.web.controller.candidate;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.enterprise.service.RescheduleRequestService;

/** 仅操作当前登录候选人自己的预约，不接受客户端指定候选人或企业。 */
@RestController
@RequestMapping("/candidate/interview/reschedule-requests")
public class CandidateRescheduleRequestController extends BaseController
{
    @Autowired private RescheduleRequestService requestService;

    @GetMapping
    public TableDataInfo list(@RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(requestService.own(getUserId(), pageNum, pageSize));
    }

    @PostMapping("/{appointmentId}")
    public AjaxResult submit(@PathVariable Long appointmentId, @RequestBody Map<String, String> body)
    {
        return success(requestService.submit(getUserId(), appointmentId,
                body.get("newStartTime"), body.get("reason")));
    }
}
