package com.ruoyi.web.controller.enterprise;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.EnterpriseNoticeDestinationService;

@RestController
@RequestMapping("/enterprise/system-notices")
public class EnterpriseNoticeDestinationController extends BaseController
{
    @Autowired private EnterpriseNoticeDestinationService destinations;
    @GetMapping("/{messageId}/destination")
    public AjaxResult destination(@PathVariable Long messageId)
    {
        return success(destinations.resolve(getUserId(),messageId));
    }
}
