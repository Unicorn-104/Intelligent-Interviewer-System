package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - HR 终审与级联流转数据层
 *
 * <p>依据《业务功能分析》UC-12 步骤7-10 / UC-15：
 * 面试会话 t_int_session、评估结果 t_int_evaluation（五维评分 JSON、
 * 结构化评语、HR 审核字段）、级联规则 t_int_cascade_rule、
 * 淘汰归档 t_tal（状态日志由数据库触发器写入）、通知消息 t_msg。</p>
 *
 * @author enterprise
 */
public interface InterviewReviewMapper
{
    /** 终审列表（会话 + 评估 + 候选人/岗位信息，按企业隔离） */
    public List<Map<String, Object>> selectReviewList(@Param("companyId") Long companyId,
            @Param("status") Integer status);

    /** 评估报告详情（五维评分 JSON + 结构化评语 + 回放链接） */
    public Map<String, Object> selectReviewDetail(@Param("sessionId") Long sessionId);

    /** 会话基础信息（级联/淘汰流程使用） */
    public Map<String, Object> selectSessionBase(@Param("sessionId") Long sessionId);

    /** 更新 HR 审核状态与结论 */
    public int updateHrStatus(@Param("sessionId") Long sessionId, @Param("hrStatus") Integer hrStatus,
            @Param("hrRecommendation") Integer hrRecommendation, @Param("hrComment") String hrComment);

    /** 更新五维评分 JSON 与综合分（调整后通过） */
    public int updateDimensionScores(@Param("sessionId") Long sessionId,
            @Param("dimsJson") String dimsJson, @Param("overallScore") Double overallScore);

    /** 级联规则（模板 + 下一轮） */
    public Map<String, Object> selectCascadeRule(@Param("templateId") Long templateId,
            @Param("round") Integer round);

    /** 创建下一轮预约任务（UC-15） */
    public int insertCascadeAppointment(@Param("candidateId") Long candidateId,
            @Param("positionId") Long positionId, @Param("interviewerId") Long interviewerId,
            @Param("startTime") String startTime, @Param("endTime") String endTime);

    /** 更新候选人状态（触发器自动写状态日志） */
    public int updateTalStatus(@Param("talId") Long talId, @Param("status") Integer status);

    /** 向候选人写入通知消息 */
    public int insertMessage(@Param("receiverId") Long receiverId, @Param("title") String title,
            @Param("content") String content);
}
