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
