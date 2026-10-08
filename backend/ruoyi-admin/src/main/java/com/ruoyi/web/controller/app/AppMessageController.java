package com.ruoyi.web.controller.app;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.service.app.IAppMessageService;

/** C-App 消息中心接口。 */
@RestController
@RequestMapping("/app/messages")
public class AppMessageController extends BaseController
{
    @Autowired
    private IAppMessageService messageService;

    @GetMapping
    public AjaxResult messages(@RequestParam(required = false, defaultValue = "50") Integer limit)
    {
        return success(messageService.selectMessages(getUserId(), limit));
    }

    @Log(title = "C端消息已读", businessType = BusinessType.UPDATE)
    @PutMapping("/{category}/{messageId}/read")
    public AjaxResult markRead(@PathVariable String category, @PathVariable Long messageId)
    {
        messageService.markRead(getUserId(), category, messageId);
        return success();
    }

    @Log(title = "C端消息全部已读", businessType = BusinessType.UPDATE)
    @PutMapping("/read-all")
    public AjaxResult markAllRead()
    {
        messageService.markAllRead(getUserId());
        return success();
    }

    @GetMapping("/hr/{sessionId}/chat")
    public AjaxResult hrChat(@PathVariable Long sessionId,
                             @RequestParam(required = false, defaultValue = "100") Integer limit)
    {
        return success(messageService.selectHrChatMessages(getUserId(), sessionId, limit));
    }

    @Log(title = "C端发送HR消息", businessType = BusinessType.INSERT)
    @PostMapping("/hr/{sessionId}/chat")
    public AjaxResult sendHrChat(@PathVariable Long sessionId,
                                 @RequestBody Map<String, String> body)
    {
        messageService.sendHrChatMessage(getUserId(), sessionId, body.get("content"));
        return success();
    }
}
