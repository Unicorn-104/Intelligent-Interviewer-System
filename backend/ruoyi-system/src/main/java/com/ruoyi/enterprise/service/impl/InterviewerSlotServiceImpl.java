package com.ruoyi.enterprise.service.impl;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.mapper.InterviewerSlotMapper;
import com.ruoyi.enterprise.service.IInterviewerSlotService;

/**
 * 面试官空闲时段服务实现
 */
@Service
public class InterviewerSlotServiceImpl implements IInterviewerSlotService
{
    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("yyyy-MM-dd");

    @Autowired
    private InterviewerSlotMapper slotMapper;

    @Override
    public List<Map<String, Object>> listSlots(Long userId, String weekStart)
    {
        LocalDate monday = parseWeekStart(weekStart);
        return slotMapper.selectSlots(userId, monday + " 00:00:00", monday.plusDays(7) + " 00:00:00");
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> saveSlots(Long userId, String weekStart, List<Map<String, Object>> slots)
    {
        LocalDate monday = parseWeekStart(weekStart);
        List<Map<String, Object>> cleaned = new ArrayList<>();
        if (slots != null)
        {
            for (Map<String, Object> slot : slots)
            {
                String start = slot.get("startTime") == null ? null : String.valueOf(slot.get("startTime"));
                String end = slot.get("endTime") == null ? null : String.valueOf(slot.get("endTime"));
                if (StringUtils.isEmpty(start) || StringUtils.isEmpty(end))
                {
                    continue;
                }
                if (start.compareTo(end) >= 0)
                {
                    throw new ServiceException("结束时间必须晚于开始时间：" + start);
                }
                LocalDate day;
                try
                {
                    day = LocalDate.parse(start.substring(0, 10), DATE);
                }
                catch (Exception e)
                {
                    throw new ServiceException("空闲时段格式不正确：" + start);
                }
                if (day.isBefore(monday) || !day.isBefore(monday.plusDays(7)))
                {
                    throw new ServiceException("空闲时段必须落在当前周内：" + start);
                }
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("startTime", start);
                row.put("endTime", end);
                cleaned.add(row);
            }
        }
        String from = monday + " 00:00:00";
        String to = monday.plusDays(7) + " 00:00:00";
        slotMapper.deleteSlots(userId, from, to);
        if (!cleaned.isEmpty())
        {
            slotMapper.insertSlots(userId, cleaned);
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("weekStart", monday.toString());
        result.put("saved", cleaned.size());
        result.put("message", cleaned.isEmpty() ? "已清空本周空闲时间" : "空闲时间已保存（" + cleaned.size() + " 个时段）");
        return result;
    }

    private LocalDate parseWeekStart(String weekStart)
    {
        if (StringUtils.isEmpty(weekStart))
        {
            LocalDate today = LocalDate.now();
            return today.with(DayOfWeek.MONDAY);
        }
        try
        {
            return LocalDate.parse(weekStart.substring(0, 10), DATE);
        }
        catch (Exception e)
        {
            throw new ServiceException("weekStart 格式不正确，应为 yyyy-MM-dd");
        }
    }
}
