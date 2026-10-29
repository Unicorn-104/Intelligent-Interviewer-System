package com.ruoyi.system.service.impl;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.service.IDashboardService;

/**
 * 招聘总览 服务实现
 *
 * @author ruoyi
 */
@Service
public class DashboardServiceImpl implements IDashboardService
{
    /** 候选人状态中文映射（四态收敛：0-已投递、2-待面试、3-已淘汰、4-已录用） */
    private static final Map<Integer, String> STATUS_TEXT = new LinkedHashMap<>();
    static
    {
        STATUS_TEXT.put(0, "已投递");
        STATUS_TEXT.put(2, "待面试");
        STATUS_TEXT.put(3, "已淘汰");
        STATUS_TEXT.put(4, "已录用");
    }

    @Autowired
    private DashboardMapper dashboardMapper;

    @Override
    public Map<String, Object> getOverview(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        if (companyId == null)
        {
            companyId = 1L;
        }

        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("activePositions", dashboardMapper.countActivePositions(companyId));
        stats.put("resumeCount", dashboardMapper.countResumes(companyId));
        stats.put("pendingInterviews", dashboardMapper.countPendingInterviews(companyId));
        stats.put("weeklyCompleted", dashboardMapper.countWeeklyCompletedInterviews(companyId));

        Map<String, Object> funnel = buildFunnel(dashboardMapper.selectFunnel(companyId));

        List<Map<String, Object>> todos = buildTodos(companyId);

        List<Map<String, Object>> timeline = buildTimeline(dashboardMapper.selectRecentActivities(companyId));

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("companyId", companyId);
        result.put("stats", stats);
        result.put("funnel", funnel);
        result.put("todos", todos);
        result.put("timeline", timeline);
        return result;
    }

    private Map<String, Object> buildFunnel(Map<String, Object> row)
    {
        long applied = toLong(row, "applied");
        long screened = toLong(row, "screened");
        long interviewing = toLong(row, "interviewing");
        long pendingInterview = toLong(row, "pendingInterview");
        long rejected = toLong(row, "rejected");
        long hired = toLong(row, "hired");
        double conversion = applied == 0 ? 0.0 : Math.round(hired * 1000.0 / applied) / 10.0;

        Map<String, Object> funnel = new LinkedHashMap<>();
        funnel.put("applied", applied);
        funnel.put("screened", screened);
        funnel.put("interviewing", interviewing);
        funnel.put("pendingInterview", pendingInterview);
        funnel.put("rejected", rejected);
        funnel.put("hired", hired);
        funnel.put("conversion", conversion);
        return funnel;
    }

    private List<Map<String, Object>> buildTodos(Long companyId)
    {
        List<Map<String, Object>> todos = new ArrayList<>();

        Map<String, Object> pending = dashboardMapper.selectTodoPendingConfirm(companyId);
        if (pending != null)
        {
            todos.add(todo("待确认面试", "blue", "/enterprise/interviews",
                    str(pending, "positionTitle") + " · " + str(pending, "candidateName") + " · " + str(pending, "startTime")));
        }

        Map<String, Object> finalReview = dashboardMapper.selectTodoFinalReview(companyId);
        if (finalReview != null)
        {
            String talId = str(finalReview, "talId");
            String go = StringUtils.isEmpty(talId) ? "/enterprise/candidates" : "/enterprise/candidates/" + talId + "/process";
            todos.add(todo("待终审候选人", "cyan", go,
                    str(finalReview, "positionTitle") + " · " + str(finalReview, "candidateName")));
        }

        Map<String, Object> upcoming = dashboardMapper.selectTodoUpcomingInterview(companyId);
        if (upcoming != null)
        {
            String peerId = str(upcoming, "peerId");
            String candidateName = str(upcoming, "candidateName");
            // 即将开始的面试直接定位到该候选人的消息会话
            String go = StringUtils.isEmpty(peerId)
                    ? "/enterprise/messages"
                    : "/enterprise/messages?peerId=" + peerId + "&peerName=" + URLEncoder.encode(candidateName, StandardCharsets.UTF_8);
            todos.add(todo("即将开始的面试", "orange", go,
                    str(upcoming, "positionTitle") + " · " + candidateName + " · " + str(upcoming, "startTime")));
        }
        return todos;
    }

    private Map<String, Object> todo(String title, String tone, String go, String meta)
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("title", title);
        map.put("tone", tone);
        map.put("go", go);
        map.put("meta", meta);
        return map;
    }

    private List<Map<String, Object>> buildTimeline(List<Map<String, Object>> rows)
    {
        List<Map<String, Object>> timeline = new ArrayList<>();
        for (Map<String, Object> row : rows)
        {
            String name = str(row, "candidateName");
            int status = (int) toLong(row, "toStatus");
            String text = name + " " + STATUS_TEXT.getOrDefault(status, "状态更新");
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("text", text);
            item.put("time", relativeTime(str(row, "createdAt")));
            timeline.add(item);
        }
        return timeline;
    }

    private String relativeTime(String createdAt)
    {
        if (StringUtils.isEmpty(createdAt))
        {
            return "";
        }
        try
        {
            Date date = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").parse(createdAt);
            long diff = System.currentTimeMillis() - date.getTime();
            long minute = 60_000L;
            long hour = 60 * minute;
            long day = 24 * hour;
            if (diff < minute)
            {
                return "刚刚";
            }
            else if (diff < hour)
            {
                return (diff / minute) + " 分钟前";
            }
            else if (diff < day)
            {
                return (diff / hour) + " 小时前";
            }
            else if (diff < 2 * day)
            {
                return "昨天 " + new SimpleDateFormat("HH:mm").format(date);
            }
            else
            {
                return new SimpleDateFormat("MM-dd HH:mm").format(date);
            }
        }
        catch (Exception e)
        {
            return createdAt;
        }
    }

    private long toLong(Map<String, Object> map, String key)
    {
        Object value = map == null ? null : map.get(key);
        return value == null ? 0L : ((Number) value).longValue();
    }

    private String str(Map<String, Object> map, String key)
    {
        Object value = map == null ? null : map.get(key);
        return value == null ? "" : value.toString();
    }
}
