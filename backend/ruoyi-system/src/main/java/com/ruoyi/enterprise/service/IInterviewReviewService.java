package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - HR 终审与级联流转服务层
 *
 * <p>依据《业务功能分析》UC-12 步骤7-10 与 UC-15。</p>
 *
 * @author enterprise
 */
public interface IInterviewReviewService
{
    /**
     * 待终审列表（UC-12 步骤7）：面试会话 + 评估结果 + 候选人信息
     */
    public List<Map<String, Object>> listReviews(Long userId, Integer status, Integer pageNum, Integer pageSize);

    /**
     * 评估报告详情（UC-12 步骤7）：五维评分 + 结构化评语 + 回放链接
     */
    public Map<String, Object> getReviewDetail(Long userId, Long sessionId);

    /**
     * 确认通过（UC-12 步骤8-9）：终面 → Offer 流程；非终面 → 级联下一轮
     */
    public Map<String, Object> confirm(Long userId, Long sessionId, Boolean isFinal);

    /**
     * 调整后通过（UC-12 步骤8）：修改五维评分后确认（重算综合分）
     */
    public Map<String, Object> adjust(Long userId, Long sessionId, Map<String, Object> dims);

    /**
     * 驳回淘汰（UC-12 步骤10）：淘汰归档人才库 + 感谢信
     */
    public Map<String, Object> reject(Long userId, Long sessionId, String reason);

    /**
     * 级联流转（UC-15）：按级联规则阈值判断，达标创建下一轮预约任务，未达标走淘汰
     */
    public Map<String, Object> cascade(Long userId, Long sessionId);
}
