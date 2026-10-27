package com.ruoyi.web.controller.system;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.impl.ImReadReceiptService;

/** 双端共用的已显示消息确认，身份仅来自登录态。 */
@RestController
@RequestMapping("/system/im/sessions")
public class ImReadReceiptController extends BaseController
{
    @Autowired private ImReadReceiptService receipts;

    @PutMapping("/{sessionId}/receipts")
    public AjaxResult acknowledge(@PathVariable Long sessionId, @RequestBody Map<String, Long> body)
    {
        return success(receipts.acknowledge(getUserId(), sessionId, body.get("lastMessageId")));
    }
}
