package com.ruoyi.web.controller.app;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.app.IAppMessageThreadService;

/** 保留原消息接口，独立提供分组与历史，登录身份始终由服务端获取。 */
@RestController
@RequestMapping("/app/messages/threads")
public class AppMessageThreadController extends BaseController
{
    @Autowired private IAppMessageThreadService service;

    @GetMapping
    public AjaxResult threads(@RequestParam(defaultValue = "ALL") String category,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd HH:mm:ss") Date beforeTime,
            @RequestParam(required = false) Long beforeId, @RequestParam(required = false) String beforeType,
            @RequestParam(required = false) Integer limit)
    {
        return success(service.threads(getUserId(), category, beforeTime, beforeId, beforeType, limit));
    }

    @GetMapping("/{type}/{id}/events")
    public AjaxResult events(@PathVariable String type, @PathVariable Long id,
            @RequestParam(required = false) Long beforeId, @RequestParam(required = false) Integer limit)
    {
        return success(service.events(getUserId(), type, id, beforeId, limit));
    }

    @PutMapping("/{type}/{id}/read")
    public AjaxResult read(@PathVariable String type, @PathVariable Long id, @RequestBody ReadRequest body)
    {
        service.markRead(getUserId(), type, id, body.getMessageIds());
        return success();
    }

    public static class ReadRequest
    {
        private List<Long> messageIds;
        public List<Long> getMessageIds() { return messageIds; }
        public void setMessageIds(List<Long> messageIds) { this.messageIds = messageIds; }
    }
}
