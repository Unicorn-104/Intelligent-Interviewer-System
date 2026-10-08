package com.ruoyi.system.service.app;

import java.util.List;
import com.ruoyi.system.domain.app.AppChatMessage;
import com.ruoyi.system.domain.app.AppMessageSummary;

/** C-App 消息中心服务。 */
public interface IAppMessageService
{
    List<AppMessageSummary> selectMessages(Long userId, Integer limit);

    void markRead(Long userId, String category, Long messageId);

    void markAllRead(Long userId);

    List<AppChatMessage> selectHrChatMessages(Long userId, Long sessionId, Integer limit);

    void sendHrChatMessage(Long userId, Long sessionId, String content);
}
