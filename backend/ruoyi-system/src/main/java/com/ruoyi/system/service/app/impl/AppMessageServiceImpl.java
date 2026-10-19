package com.ruoyi.system.service.app.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.app.AppChatMessage;
import com.ruoyi.system.domain.app.AppMessageSummary;
import com.ruoyi.system.mapper.app.AppMessageMapper;
import com.ruoyi.system.service.app.IAppMessageService;

@Service
public class AppMessageServiceImpl implements IAppMessageService
{
    @Autowired
    private AppMessageMapper messageMapper;

    @Override
    public List<AppMessageSummary> selectMessages(Long userId, Integer limit)
    {
        int safeLimit = limit == null ? 50 : Math.max(1, Math.min(limit, 100));
        return messageMapper.selectMessages(userId, safeLimit);
    }

    @Override
    @Transactional
    public void markRead(Long userId, String category, Long messageId)
    {
        if (messageId == null)
        {
            throw new ServiceException("消息标识不能为空");
        }
        if ("SYSTEM".equalsIgnoreCase(category))
        {
            messageMapper.markSystemMessageRead(userId, messageId);
            return;
        }
        if ("HR".equalsIgnoreCase(category))
        {
            messageMapper.markHrSessionRead(userId, messageId);
            return;
        }
        if ("COMPANY".equalsIgnoreCase(category))
        {
            messageMapper.markCompanyMessagesRead(userId, messageId);
            return;
        }
        throw new ServiceException("不支持的消息类型");
    }

    @Override
    @Transactional
    public void markAllRead(Long userId)
    {
        messageMapper.markAllSystemMessagesRead(userId);
        messageMapper.markAllHrSessionsRead(userId);
    }

    @Override
    public List<AppChatMessage> selectHrChatMessages(Long userId, Long sessionId, Integer limit)
    {
        if (sessionId == null)
        {
            throw new ServiceException("会话标识不能为空");
        }
        int safeLimit = limit == null ? 100 : Math.max(1, Math.min(limit, 200));
        return messageMapper.selectHrChatMessages(userId, sessionId, safeLimit);
    }

    @Override
    @Transactional
    public void sendHrChatMessage(Long userId, Long sessionId, String content)
    {
        String normalized = content == null ? "" : content.trim();
        if (normalized.isEmpty())
        {
            throw new ServiceException("消息内容不能为空");
        }
        if (normalized.length() > 1000)
        {
            throw new ServiceException("消息内容不能超过1000个字符");
        }
        int inserted = messageMapper.insertHrChatMessage(userId, sessionId, normalized);
        if (inserted == 0)
        {
            throw new ServiceException("会话不存在或无权访问");
        }
        messageMapper.updateHrSessionAfterCandidateMessage(userId, sessionId, normalized);
    }
}
