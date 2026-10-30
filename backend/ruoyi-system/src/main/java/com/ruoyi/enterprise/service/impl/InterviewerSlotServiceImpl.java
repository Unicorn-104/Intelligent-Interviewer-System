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
        // 与预约创建/改期共用面试官行锁：串行化并发保存时段与并发预约，
        // 避免保存期间的删除操作与并发创建的预约时段互相破坏。
        if (slotMapper.lockInterviewer(userId) == null)
            throw new ServiceException("面试官不存在或已停用");
        // 保存的可用时段与待确认/已确认面试冲突时整笔拒绝：保留已有预约，不静默取消、不自动改期。
        for (Map<String, Object> row : cleaned)
        {
            List<Map<String, Object>> conflicts = slotMapper.selectConflictingAppointments(
                    userId, String.valueOf(row.get("startTime")), String.valueOf(row.get("endTime")));
            if (!conflicts.isEmpty())
            {
                StringBuilder detail = new StringBuilder();
                for (Map<String, Object> conflict : conflicts)
                {
                    if (detail.length() > 0) detail.append("；");
                    detail.append(conflict.get("startTime")).append(" 至 ").append(conflict.get("endTime"));
                }
                throw new ServiceException("时段 " + row.get("startTime") + " 至 " + row.get("endTime")
                        + " 与已安排的面试冲突（" + detail + "），请先调整面试或换用其他空闲时段");
            }
        }
        String from = monday + " 00:00:00";
        String to = monday.plusDays(7) + " 00:00:00";
        // 只删除未被有效预约引用的时段；被待确认/已确认预约引用的占用时段保留，
        // 已取消预约引用的遗留时段与孤立占用时段随本次保存一并清理。
        slotMapper.deleteUnreferencedSlots(userId, from, to);
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
