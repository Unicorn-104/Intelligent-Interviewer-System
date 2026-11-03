package com.ruoyi.system.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 面试报告自动生成数据层：报告状态机、生成数据装配、评估行落库。
 *
 * @author ruoyi
 */
public interface InterviewReportMapper
{
    /**
     * CAS 抢占生成权：未触发、失败，或「生成中」已超时的场次可被重新抢占。
     *
     * @return 影响行数，0 表示已被其它线程抢占或状态不允许生成
     */
    public int claimReport(@Param("sessionId") Long sessionId, @Param("staleMinutes") int staleMinutes);

    /**
     * 标记报告生成成功（状态机：生成中 -> 成功）
     */
    public int markReportSuccess(@Param("sessionId") Long sessionId);

    /**
     * 标记报告生成失败（状态机：生成中 -> 失败），并累加重试次数
     */
    public int markReportFailed(@Param("sessionId") Long sessionId, @Param("error") String error);

    /**
     * 重置重试次数（HR 手动重试前调用，使累计失败次数重新开始）
     */
    public int resetReportRetry(@Param("sessionId") Long sessionId);

    /**
     * 报告生成所需的场次、岗位与进度上下文
     */
    public Map<String, Object> selectReportSource(@Param("sessionId") Long sessionId);

    /**
     * 逐字稿（剔除系统消息），按对话序号升序
     */
    public List<Map<String, Object>> selectTranscript(@Param("sessionId") Long sessionId);

    /**
     * 面试提纲题目（用于按题目边界分段）
     */
    public List<Map<String, Object>> selectQuestions(@Param("sessionId") Long sessionId);

    /**
     * 写入 AI 评估结论（HR 审核字段保持默认待审，由 HR 终审时更新）
     */
    public int insertEvaluation(Map<String, Object> params);

    /**
     * 候选人可见的报告摘要（不含 evidence / risks / gaps）
     */
    public Map<String, Object> selectCandidateReport(@Param("sessionId") Long sessionId);

    /**
     * 定时补偿候选：正常结束、未触发/超时生成中/失败且未达重试上限的场次
     */
    public List<Long> selectRetryCandidates(@Param("scanDays") int scanDays,
            @Param("staleMinutes") int staleMinutes, @Param("maxRetry") int maxRetry);
}
