package com.ruoyi.web.controller.system;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.file.FileUploadUtils;
import com.ruoyi.common.utils.file.FileUtils;
import com.ruoyi.framework.config.ServerConfig;
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
    private static final long MAX_ATTACHMENT_SIZE = 10 * 1024 * 1024L;
    private static final Set<String> ALLOWED_ATTACHMENT_EXTENSIONS = new HashSet<>(Arrays.asList(
            "bmp", "gif", "jpg", "jpeg", "png", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "txt", "zip"));

    @Autowired
    private IImService imService;

    @Autowired
    private ServerConfig serverConfig;

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
     * 上传聊天附件。上传完成后由客户端把返回地址写入 type=2/3 的消息，企业端与求职者端共用此接口。
     */
    @PostMapping(value = "/attachments", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AjaxResult uploadAttachment(@RequestPart("file") MultipartFile file) throws Exception
    {
        if (file == null || file.isEmpty())
        {
            return error("附件不能为空");
        }
        if (file.getSize() > MAX_ATTACHMENT_SIZE)
        {
            return error("附件不能超过10MB");
        }
        if (file.getOriginalFilename() == null || file.getOriginalFilename().trim().isEmpty())
        {
            return error("附件文件名不能为空");
        }
        String extension = FileUploadUtils.getExtension(file).toLowerCase();
        if (!ALLOWED_ATTACHMENT_EXTENSIONS.contains(extension))
        {
            return error("仅支持图片、PDF、Office、TXT或ZIP文件");
        }
        String fileName = FileUploadUtils.upload(RuoYiConfig.getUploadPath(), file);
        AjaxResult result = success();
        result.put("url", serverConfig.getUrl() + fileName);
        result.put("fileName", fileName);
        result.put("newFileName", FileUtils.getName(fileName));
        result.put("originalFilename", file.getOriginalFilename());
        result.put("contentType", file.getContentType());
        result.put("size", file.getSize());
        return result;
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
