package com.ruoyi.system.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.ImMessage;

/**
 * IM消息 数据层
 *
 * @author ruoyi
 */
public interface ImMessageMapper
{
    /**
     * 查询指定会话的消息列表（按发送时间升序）
     */
    public List<ImMessage> selectMessageListBySession(@Param("sessionId") Long sessionId);

    /**
     * 新增消息
     */
    public int insertMessage(ImMessage message);

    /** 只查询当前接收人的系统通知，使用消息ID游标分页。 */
    List<Map<String, Object>> selectNotifications(@Param("userId") Long userId,
            @Param("beforeId") Long beforeId, @Param("limit") int limit);

    Map<String, Object> selectNotification(@Param("userId") Long userId, @Param("messageId") Long messageId);

    int countUnreadNotifications(@Param("userId") Long userId);

    int readNotification(@Param("userId") Long userId, @Param("messageId") Long messageId);

    int readAllNotifications(@Param("userId") Long userId);

    /**
     * 快捷回复模板列表
     */
    public List<Map<String, Object>> selectQuickReplies();

    /**
     * 新增快捷回复模板
     */
    public int insertQuickReply(@Param("category") String category, @Param("content") String content);

    /**
     * 修改快捷回复模板
     */
    public int updateQuickReply(@Param("id") Long id, @Param("category") String category, @Param("content") String content);

    /**
     * 删除快捷回复模板
     */
    public int deleteQuickReply(@Param("id") Long id);
}
