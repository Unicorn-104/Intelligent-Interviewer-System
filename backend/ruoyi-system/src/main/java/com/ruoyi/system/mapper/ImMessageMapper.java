package com.ruoyi.system.mapper;

import java.util.List;
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
}
