package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - AI 初筛与智能匹配服务层
 *
 * <p>依据《业务功能分析》UC-04（硬性条件自动过滤）、
 * UC-05（AI 多维度匹配与评分排序）、UC-06（短名单 HR 复核）。</p>
 *
 * @author enterprise
 */
public interface IScreeningService
{
    /**
     * 触发筛选任务（UC-04/UC-05 步骤1-4）：硬性过滤 + 加权评分并落库
     *
     * @return 任务汇总（任务ID=岗位ID、候选人数、通过数、Top N）
     */
    public Map<String, Object> triggerScreening(Long userId, Long positionId, Integer topN);

    /**
     * 筛选任务列表（UC-05 步骤1）：按岗位聚合流程实例状态
     */
    public List<Map<String, Object>> listTasks(Long userId, Integer pageNum, Integer pageSize);

    /**
     * 匹配度评分与维度明细（UC-05 步骤3-4，降序）
     */
    public List<Map<String, Object>> listResults(Long userId, Long taskId);

    /**
     * 推荐短名单（UC-05 步骤5：Top N 降序）
     */
    public List<Map<String, Object>> listShortlist(Long userId, Long taskId, Integer topN);

    /**
     * AI 推荐报告（UC-05 步骤6-7）：匹配点/风险点/待核实点
     */
    public Map<String, Object> getReport(Long userId, Long resultId);

    /**
     * 个性化招呼语（UC-05 步骤8）
     */
    public Map<String, Object> getGreeting(Long userId, Long resultId);

    /**
     * HR 复核（UC-06）：确认通过（tal_status→初筛通过，触发器自动写状态日志）/ 调整评分
     */
    public Map<String, Object> reviewResult(Long userId, Long resultId, Boolean approved, Double adjustScore);
}
