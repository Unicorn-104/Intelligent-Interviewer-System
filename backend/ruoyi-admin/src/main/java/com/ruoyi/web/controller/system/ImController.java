package com.ruoyi.web.controller.system;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.service.IImService;

/**
 * IM即时通讯（消息中心）
 *
 * 会话收发接口供已登录的求职者与企业用户共用；快捷回复模板仍仅允许企业角色管理。
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

    /** 系统通知复用 t_msg，接收人始终来自登录态。 */
    @GetMapping("/notifications")
    public AjaxResult notifications(@RequestParam(required = false) Long beforeId,
            @RequestParam(defaultValue = "50") Integer limit)
    {
        List<Map<String, Object>> rows = imService.selectNotifications(getUserId(), beforeId, limit);
        AjaxResult result = success(rows);
        result.put("unreadCount", imService.countUnreadNotifications(getUserId()));
        return result;
    }

    @PutMapping("/notifications/{messageId}/read")
    public AjaxResult readNotification(@PathVariable Long messageId)
    {
        imService.readNotification(getUserId(), messageId);
        return success();
    }

    @PutMapping("/notifications/read-all")
    public AjaxResult readAllNotifications()
    {
        imService.readAllNotifications(getUserId());
        return success();
    }

    /**
     * 快捷回复模板列表
     */
    @GetMapping("/quick-replies")
    @PreAuthorize("@ss.hasAnyRoles('biz_1,biz_2,biz_3')")
    public AjaxResult quickReplies()
    {
        return success(imService.selectQuickReplies());
    }

    /**
     * 保存快捷回复模板（id 为空则新增）
     */
    @PostMapping("/quick-replies")
    @PreAuthorize("@ss.hasAnyRoles('biz_1,biz_2,biz_3')")
    public AjaxResult saveQuickReply(@RequestBody Map<String, Object> body)
    {
        Object id = body.get("id");
        Long tplId = id == null ? null : Long.valueOf(id.toString());
        return toAjax(imService.saveQuickReply(tplId, str(body, "category"), str(body, "content")));
    }

    /**
     * 删除快捷回复模板
     */
    @DeleteMapping("/quick-replies/{id}")
    @PreAuthorize("@ss.hasAnyRoles('biz_1,biz_2,biz_3')")
    public AjaxResult deleteQuickReply(@PathVariable Long id)
    {
        return toAjax(imService.deleteQuickReply(id));
    }

    private String str(Map<String, Object> body, String key)
    {
        Object v = body.get(key);
        return v == null ? null : v.toString();
    }
}
