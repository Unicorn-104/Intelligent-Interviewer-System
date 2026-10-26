package com.ruoyi.web.controller.enterprise;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.enterprise.service.RescheduleRequestService;

@RestController
@RequestMapping("/enterprise/interview/reschedule-requests")
public class RescheduleReviewController extends BaseController
{
    @Autowired private RescheduleRequestService requestService;

    @GetMapping
    public TableDataInfo list(@RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(requestService.list(getUserId(), status, pageNum, pageSize));
    }

    @GetMapping("/{requestId}")
    public AjaxResult detail(@PathVariable Long requestId)
    {
        return success(requestService.detail(getUserId(), requestId));
    }

    @PutMapping("/{requestId}/review")
    public AjaxResult review(@PathVariable Long requestId, @RequestBody Map<String, String> body)
    {
        return success(requestService.review(getUserId(), requestId, body.get("decision"), body.get("note")));
    }
}
