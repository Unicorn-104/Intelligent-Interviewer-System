package com.ruoyi.system.service;

import java.util.List;
import java.util.Map;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;

/**
 * IM即时通讯 服务层
 *
 * @author ruoyi
 */
public interface IImService
{
    /**
     * 查询指定用户的会话列表
     */
    public List<ImSession> selectSessionList(Long userId);

    /**
     * 查询会话消息列表（校验归属）
     */
    public List<ImMessage> selectMessageList(Long sessionId, Long userId);

    /**
     * 发送消息。若 sessionId 为空则按 peerId 查找或创建会话。
     *
     * @return 消息所属会话ID
     */
    public Long sendMessage(ImMessage message, Long senderId, Long peerId);

    /**
     * 清空当前用户在指定会话的未读数
     */
    public int clearUnread(Long sessionId, Long userId);

    /**
     * 清空当前用户全部会话未读数
     */
    public int clearAllUnread(Long userId);

    /**
     * 统计当前用户未读总数
     */
    public int sumUnread(Long userId);

    /**
     * 快捷回复模板列表
     */
    public List<Map<String, Object>> selectQuickReplies();

    /**
     * 保存快捷回复模板（id 为空则新增）
     */
    public int saveQuickReply(Long id, String category, String content);

    /**
     * 删除快捷回复模板
     */
    public int deleteQuickReply(Long id);
}
