package com.ruoyi.web.controller.system;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.service.IImService;

/**
 * IM即时通讯（消息中心）
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/system/im")
public class ImController extends BaseController
{
    @Autowired
    private IImService imService;

    /**
     * 当前用户的会话列表
     */
    @GetMapping("/sessions")
    public AjaxResult sessions()
    {
        List<ImSession> list = imService.selectSessionList(getUserId());
        return success(list);
    }

    /**
     * 指定会话的消息列表
     */
    @GetMapping("/sessions/{sessionId}/messages")
    public AjaxResult messages(@PathVariable Long sessionId)
    {
        List<ImMessage> list = imService.selectMessageList(sessionId, getUserId());
        return success(list);
    }

    /**
     * 发送消息。sessionId 为空时按 peerId 查找或创建会话。
     */
    @PostMapping("/messages")
    public AjaxResult send(@RequestBody ImMessage message)
    {
        Long sessionId = imService.sendMessage(message, getUserId(), message.getPeerId());
        AjaxResult ajax = AjaxResult.success();
        ajax.put("sessionId", sessionId);
        return ajax;
    }

    /**
     * 清空指定会话未读数
     */
    @PutMapping("/sessions/{sessionId}/read")
    public AjaxResult read(@PathVariable Long sessionId)
    {
        imService.clearUnread(sessionId, getUserId());
        return success();
    }

    /**
     * 清空全部会话未读数
     */
    @PutMapping("/read-all")
    public AjaxResult readAll()
    {
        imService.clearAllUnread(getUserId());
        return success();
    }

    /**
     * 当前用户未读总数（侧边栏角标）
     */
    @GetMapping("/unread-count")
    public AjaxResult unreadCount()
    {
        AjaxResult ajax = AjaxResult.success();
        ajax.put("count", imService.sumUnread(getUserId()));
        return ajax;
    }
}
