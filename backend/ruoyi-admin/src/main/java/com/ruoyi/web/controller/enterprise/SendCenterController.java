package com.ruoyi.web.controller.enterprise;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.ISendCenterService;

/**
 * 笔试与面试发送中心
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/enterprise/send")
public class SendCenterController extends BaseController
{
    @Autowired
    private ISendCenterService sendCenterService;

    /** 发送上下文：投递状态、阶段与通过情况、笔试前置、在途预约 */
    @GetMapping("/context")
    public AjaxResult context(@RequestParam Long candidateId, @RequestParam Long positionId)
    {
        return success(sendCenterService.getContext(getUserId(), candidateId, positionId));
    }
}
