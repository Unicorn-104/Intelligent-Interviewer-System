package com.ruoyi.system.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.ImSession;

/**
 * IM会话 数据层
 *
 * @author ruoyi
 */
public interface ImSessionMapper
{
    /**
     * 查询指定用户的会话列表（含对方昵称、头像、本人未读数）
     */
    public List<ImSession> selectSessionListByUser(@Param("userId") Long userId);

    /**
     * 按会话ID与用户ID查询单个会话（用于校验访问权限）
     */
    public ImSession selectSessionByIdAndUser(@Param("sessionId") Long sessionId, @Param("userId") Long userId);

    /**
     * 查询两个用户之间已存在的会话
     */
    public ImSession selectSessionByUsers(@Param("userAId") Long userAId, @Param("userBId") Long userBId);

    /**
     * 新增会话
     */
    public int insertSession(ImSession session);

    /**
     * 更新会话最近消息摘要与时间，并累加接收方未读数
     */
    public int updateSessionOnSend(@Param("sessionId") Long sessionId, @Param("lastMessage") String lastMessage, @Param("receiverId") Long receiverId);

    /**
     * 清空当前用户在该会话的未读数
     */
    public int clearUnread(@Param("sessionId") Long sessionId, @Param("userId") Long userId);

    /**
     * 清空当前用户全部会话的未读数
     */
    public int clearAllUnread(@Param("userId") Long userId);

    /**
     * 统计当前用户全部会话未读总数
     */
    public int sumUnreadByUser(@Param("userId") Long userId);
}
