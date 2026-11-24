package com.ruoyi.system.service.app.impl;

import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.app.AppMessageThread;
import com.ruoyi.system.mapper.app.AppMessageThreadMapper;
import com.ruoyi.system.service.app.IAppMessageThreadService;

/** 分组只改变读取视图，不合并或删除原始通知。 */
@Service
public class AppMessageThreadService implements IAppMessageThreadService
{
    @Autowired private AppMessageThreadMapper mapper;

    @Override
    public Map<String, Object> threads(Long userId, String category, Date beforeTime, Long beforeId, Integer limit)
    {
        return threads(userId, category, beforeTime, beforeId, null, limit);
    }

    @Override
    public Map<String, Object> threads(Long userId, String category, Date beforeTime, Long beforeId, String beforeType, Integer limit)
    {
        String normalized = normalize(category);
        if (normalized.isEmpty()) normalized = "ALL";
        if (!List.of("ALL", "HR", "COMPANY", "SYSTEM").contains(normalized))
            throw new ServiceException("不支持的消息分类");
        if ((beforeTime == null) != (beforeId == null) || (beforeId != null && beforeId <= 0))
            throw new ServiceException("消息分页标识无效");
        if ((beforeType != null && !List.of("HR", "COMPANY", "SYSTEM", "INTERVIEW").contains(beforeType))
                || ("ALL".equals(normalized) && beforeTime != null && beforeType == null))
            throw new ServiceException("消息分页类型无效");
        int size = size(limit);
        boolean hasReschedule = mapper.hasRescheduleTable();
        boolean hasInterest = mapper.hasInterestTable();
        List<AppMessageThread> rows = mapper.selectThreads(userId, normalized, beforeTime, beforeId, beforeType, size + 1, hasReschedule, hasInterest);
        Map<String, Object> result = page(rows, size);
        Map<String, Integer> counts = new LinkedHashMap<>();
        for (String key : List.of("HR", "COMPANY", "SYSTEM")) counts.put(key, 0);
        for (AppMessageThread count : mapper.selectUnreadCounts(userId, hasReschedule, hasInterest))
            counts.put(count.getCategory(), count.getUnreadCount());
        result.put("unreadCounts", counts);
        return result;
    }

    @Override
    public Map<String, Object> events(Long userId, String type, Long id, Long beforeId, Integer limit)
    {
        String normalized = requireThread(type, id);
        if (beforeId != null && beforeId <= 0) throw new ServiceException("消息分页标识无效");
        int size = size(limit);
        return page(mapper.selectEvents(userId, normalized, id, beforeId, size + 1, mapper.hasRescheduleTable()), size);
    }

    @Transactional(rollbackFor = Exception.class)
    @Override
    public void markRead(Long userId, String type, Long id, List<Long> ids)
    {
        String normalized = requireThread(type, id);
        if (ids == null || ids.isEmpty() || ids.size() > 100
                || ids.stream().anyMatch(value -> value == null || value <= 0))
            throw new ServiceException("请选择有效的消息记录");
        List<Long> unique = ids.stream().distinct().toList();
        List<Long> allowed = mapper.selectReadableIds(userId, normalized, id, unique, mapper.hasRescheduleTable());
        if (allowed.size() != unique.size() || !allowed.containsAll(unique))
            throw new ServiceException("消息不存在或无权访问");
        // 只标记本次已加载的 ID，保留未加载历史和并发新通知的未读状态。
        mapper.markEventsRead(userId, unique);
    }

    private String requireThread(String type, Long id)
    {
        String normalized = normalize(type);
        if (id == null || !("SYSTEM".equals(normalized) ? id == 0
                : List.of("COMPANY", "INTERVIEW").contains(normalized) && id > 0))
            throw new ServiceException("消息分组无效");
        return normalized;
    }

    private String normalize(String value)
    {
        return value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
    }

    private int size(Integer value) { return value == null ? 20 : Math.max(1, Math.min(value, 50)); }

    private Map<String, Object> page(List<AppMessageThread> rows, int size)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("hasMore", rows.size() > size);
        result.put("items", rows.subList(0, Math.min(size, rows.size())));
        return result;
    }
}
