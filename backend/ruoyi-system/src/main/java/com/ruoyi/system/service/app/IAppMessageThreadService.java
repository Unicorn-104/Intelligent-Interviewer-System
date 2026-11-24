package com.ruoyi.system.service.app;

import java.util.Date;
import java.util.List;
import java.util.Map;

/** C-App 消息分组与历史服务。 */
public interface IAppMessageThreadService
{
    Map<String, Object> threads(Long userId, String category, Date beforeTime, Long beforeId, Integer limit);

    Map<String, Object> threads(Long userId, String category, Date beforeTime, Long beforeId, String beforeType, Integer limit);

    Map<String, Object> events(Long userId, String threadType, Long threadId, Long beforeId, Integer limit);

    void markRead(Long userId, String threadType, Long threadId, List<Long> messageIds);
}
