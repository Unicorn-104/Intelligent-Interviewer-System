package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 笔试判分与成绩报告数据层
 *
 * <p>覆盖客观题自动判分（t_exam_answer 对错与得分回填）、成绩报告
 * （t_exam_result）、考试记录评分状态（t_exam_record）与人才库归档
 * （t_tal 状态更新，状态日志由数据库触发器写入）。</p>
 *
 * @author enterprise
 */
public interface ExamGradeMapper
{
    /** 判分视角的记录上下文（含岗位归属企业、阈值与自动流转配置） */
    public Map<String, Object> selectRecordForGrade(@Param("recordId") Long recordId);

    /** 企业隔离视角的记录上下文（越权返回 null） */
    public Map<String, Object> selectRecordForCompany(@Param("recordId") Long recordId,
            @Param("companyId") Long companyId);

    /** 记录的作答行（关联题库标准答案与题型） */
    public List<Map<String, Object>> selectGradingAnswers(@Param("recordId") Long recordId);

    /** 回填单题判分结果 */
    public int updateAnswerGrade(@Param("eanId") Long eanId, @Param("isCorrect") Integer isCorrect,
            @Param("score") java.math.BigDecimal score);

    /** 仅回填主观题得分（不改动对错标记） */
    public int updateAnswerScore(@Param("eanId") Long eanId, @Param("score") java.math.BigDecimal score);

    /** 记录回填得分与通过状态（status：2-已交卷待主观，4-已评分） */
    public int updateRecordScored(@Param("recordId") Long recordId,
            @Param("totalScore") java.math.BigDecimal totalScore,
            @Param("passStatus") Integer passStatus, @Param("status") Integer status);

    /** 成绩报告 upsert（record 唯一键） */
    public int upsertResult(Map<String, Object> params);

    /** 人才库状态流转（归档/笔试通过），并回写最新笔试记录 */
    public int updateTalStatus(@Param("talId") Long talId, @Param("status") Integer status,
            @Param("recordId") Long recordId);

    /** 成绩报告列表（企业隔离，按交卷时间倒序） */
    public List<Map<String, Object>> selectResultList(@Param("companyId") Long companyId,
            @Param("positionId") Long positionId, @Param("passStatus") Integer passStatus);

    /** 报告明细的作答清单 */
    public List<Map<String, Object>> selectResultAnswers(@Param("recordId") Long recordId);
}
