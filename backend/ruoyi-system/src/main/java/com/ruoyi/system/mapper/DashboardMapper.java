package com.ruoyi.system.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 招聘总览数据层
 *
 * @author ruoyi
 */
public interface DashboardMapper
{
    /**
     * 查询用户绑定的公司ID（审核通过状态）
     */
    public Long selectCompanyIdByUser(@Param("userId") Long userId);

    /**
     * 统计在招岗位数
     */
    public int countActivePositions(@Param("companyId") Long companyId);

    /**
     * 统计简历总量（候选人关联的简历数）
     */
    public int countResumes(@Param("companyId") Long companyId);

    /**
     * 统计待处理面试数（待确认/已确认预约）
     */
    public int countPendingInterviews(@Param("companyId") Long companyId);

    /**
     * 统计本周已完成面试数
     */
    public int countWeeklyCompletedInterviews(@Param("companyId") Long companyId);

    /**
     * 查询招聘漏斗（近30天）
     */
    public Map<String, Object> selectFunnel(@Param("companyId") Long companyId);

    /**
     * 待办：待确认面试（取最近一条）
     */
    public Map<String, Object> selectTodoPendingConfirm(@Param("companyId") Long companyId);

    /**
     * 待办：待终审候选人（笔试通过，取最近一条）
     */
    public Map<String, Object> selectTodoFinalReview(@Param("companyId") Long companyId);

    /**
     * 待办：即将开始的面试（已确认且时间最近）
     */
    public Map<String, Object> selectTodoUpcomingInterview(@Param("companyId") Long companyId);

    /**
     * 最近动态：候选人状态流转日志（最近4条）
     */
    public List<Map<String, Object>> selectRecentActivities(@Param("companyId") Long companyId);
}
