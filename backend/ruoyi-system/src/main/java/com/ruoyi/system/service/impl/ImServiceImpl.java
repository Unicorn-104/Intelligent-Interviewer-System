package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.mapper.ImMessageMapper;
import com.ruoyi.system.mapper.ImSessionMapper;
import com.ruoyi.system.service.IImService;

/**
 * IM即时通讯 服务层实现
 *
 * @author ruoyi
 */
@Service
public class ImServiceImpl implements IImService
{
    @Autowired
    private ImSessionMapper sessionMapper;

    @Autowired
    private ImMessageMapper messageMapper;

    @Override
    public List<ImSession> selectSessionList(Long userId)
    {
        return sessionMapper.selectSessionListByUser(userId);
    }

    @Override
    public List<ImMessage> selectMessageList(Long sessionId, Long userId)
    {
        ImSession session = sessionMapper.selectSessionByIdAndUser(sessionId, userId);
        if (StringUtils.isNull(session))
        {
            throw new ServiceException("会话不存在或无权访问");
        }
        List<ImMessage> list = messageMapper.selectMessageListBySession(sessionId);
        for (ImMessage msg : list)
        {
            msg.setIsMine(userId.equals(msg.getSenderId()));
        }
        return list;
    }

    @Override
    @Transactional
    public Long sendMessage(ImMessage message, Long senderId, Long peerId)
    {
        Long sessionId = message.getSessionId();
        ImSession session = null;
        if (StringUtils.isNull(sessionId))
        {
            if (StringUtils.isNull(peerId) || peerId.equals(senderId))
            {
                throw new ServiceException("缺少会话或聊天对象");
            }
            session = sessionMapper.selectSessionByUsers(senderId, peerId);
            if (StringUtils.isNull(session))
            {
                session = new ImSession();
                session.setUserAId(senderId);
                session.setUserBId(peerId);
                sessionMapper.insertSession(session);
            }
            sessionId = session.getSessionId();
            message.setSessionId(sessionId);
        }
        else
        {
            session = sessionMapper.selectSessionByIdAndUser(sessionId, senderId);
            if (StringUtils.isNull(session))
            {
                throw new ServiceException("会话不存在或无权访问");
            }
        }

        if (StringUtils.isNull(message.getType()))
        {
            message.setType(1);
        }
        message.setSenderId(senderId);
        messageMapper.insertMessage(message);

        // 更新会话摘要与接收方未读数
        String summary = buildSummary(message);
        Long receiverId = session.getUserAId().equals(senderId) ? session.getUserBId() : session.getUserAId();
        sessionMapper.updateSessionOnSend(sessionId, summary, receiverId);
        return sessionId;
    }

    private String buildSummary(ImMessage message)
    {
        String content = StringUtils.nvl(message.getContent(), "");
        String summary;
        switch (message.getType())
        {
            case 2:
                summary = "[图片]";
                break;
            case 3:
                summary = "[文件]";
                break;
            case 5:
                summary = "[系统]";
                break;
            default:
                summary = content;
                break;
        }
        return summary.length() > 200 ? summary.substring(0, 200) : summary;
    }

    @Override
    public int clearUnread(Long sessionId, Long userId)
    {
        return sessionMapper.clearUnread(sessionId, userId);
    }

    @Override
    public int clearAllUnread(Long userId)
    {
        return sessionMapper.clearAllUnread(userId);
    }

    @Override
    public int sumUnread(Long userId)
    {
        return sessionMapper.sumUnreadByUser(userId);
    }
}
