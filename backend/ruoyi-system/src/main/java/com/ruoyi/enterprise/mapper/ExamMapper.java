package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 在线笔试（题库/试卷组卷/考试安排）数据层
 *
 * <p>对应表：t_exam_question、t_exam_paper、t_exam_paper_question、t_exam_schedule。
 * 试卷与考试安排通过 t_pos.pos_company_id 做企业数据隔离；题库为平台共享数据。</p>
 *
 * @author enterprise
 */
public interface ExamMapper
{
    /** 岗位归属校验：返回该企业在岗岗位数 */
    public int countPosition(@Param("companyId") Long companyId, @Param("positionId") Long positionId);

    /** 岗位名称（用于试卷/安排列表展示） */
    public Map<String, Object> selectPositionBrief(@Param("companyId") Long companyId, @Param("positionId") Long positionId);

    /** 岗位上下文（标题/职责描述/技能要求），供 AI 组卷命题使用 */
    public Map<String, Object> selectPositionContext(@Param("companyId") Long companyId, @Param("positionId") Long positionId);

    // ==================== 题库 ====================

    public List<Map<String, Object>> selectQuestionList(@Param("type") Integer type,
            @Param("difficulty") Integer difficulty, @Param("skillTag") String skillTag,
            @Param("keyword") String keyword, @Param("scope") String scope,
            @Param("companyId") Long companyId);

    public Map<String, Object> selectQuestionById(@Param("id") Long id);

    public int insertQuestion(Map<String, Object> params);

    public int selectLastQuestionId();

    public int updateQuestion(Map<String, Object> params);

    public int deleteQuestion(@Param("id") Long id, @Param("companyId") Long companyId);

    /** 仅补全空解析 */
    public int updateQuestionAnalysis(@Param("id") Long id, @Param("analysis") String analysis,
            @Param("forceRegenerate") boolean forceRegenerate);

    /** 按条件随机抽题；scope=platform/enterprise 限定单一题库，为空时包含两者。 */
    public List<Map<String, Object>> drawQuestions(@Param("type") Integer type,
            @Param("difficulty") Integer difficulty, @Param("skillTag") String skillTag,
            @Param("excludeIds") List<Long> excludeIds, @Param("limit") Integer limit,
            @Param("scope") String scope, @Param("companyId") Long companyId);

    /** 满足抽题条件的可用题目数 */
    public int countDrawQuestions(@Param("type") Integer type, @Param("difficulty") Integer difficulty,
            @Param("skillTag") String skillTag, @Param("scope") String scope,
            @Param("companyId") Long companyId);

    /** 投递记录所属企业 */
    public Long selectRecordCompanyId(@Param("recordId") Long recordId);

    // ==================== 试卷 ====================

    public List<Map<String, Object>> selectPaperList(@Param("companyId") Long companyId,
            @Param("positionId") Long positionId);

    public Map<String, Object> selectPaperById(@Param("companyId") Long companyId, @Param("paperId") Long paperId);

    public List<Map<String, Object>> selectPaperQuestions(@Param("paperId") Long paperId);

    public int insertPaper(Map<String, Object> params);

    public int selectLastPaperId();

    /** 最近题干（企业可见范围：平台题库 + 本企业题库），用于 AI 命题查重 */
    public List<String> selectRecentQuestionStems(@Param("companyId") Long companyId, @Param("limit") int limit);

    /** 按关键词检索题干（企业可见范围），供 AI 工具查重 */
    public List<String> searchQuestionStems(@Param("companyId") Long companyId,
            @Param("keyword") String keyword, @Param("limit") int limit);

    public int updatePaper(Map<String, Object> params);

    /** 启用/禁用试卷（企业隔离：经 t_pos.pos_company_id） */
    public int updatePaperStatus(@Param("companyId") Long companyId, @Param("paperId") Long paperId,
            @Param("status") Integer status);

    public int deletePaper(@Param("companyId") Long companyId, @Param("paperId") Long paperId);

    public int deletePaperQuestions(@Param("paperId") Long paperId);

    public int insertPaperQuestion(@Param("paperId") Long paperId, @Param("questionId") Long questionId,
            @Param("score") java.math.BigDecimal score, @Param("sortOrder") Integer sortOrder);

    // ==================== 考试安排 ====================

    public List<Map<String, Object>> selectScheduleList(@Param("companyId") Long companyId,
            @Param("positionId") Long positionId, @Param("status") Integer status);

    public Map<String, Object> selectScheduleById(@Param("companyId") Long companyId, @Param("scheduleId") Long scheduleId);

    public int insertSchedule(Map<String, Object> params);

    public int selectLastScheduleId();

    public int updateSchedule(Map<String, Object> params);

    public int updateScheduleStatus(@Param("scheduleId") Long scheduleId, @Param("status") Integer status);

    /** 按当前时间同步安排状态：待生效→进行中、进行中/待生效→已结束 */
    public int syncScheduleStatuses();

    /** 该试卷是否存在进行中的安排（删除试卷前校验） */
    public int countActiveSchedulesByPaper(@Param("paperId") Long paperId);
    public int countStartedRecords(@Param("scheduleId") Long scheduleId);

    /** 岗位流程中的笔试阶段（按阶段ID校验企业与类型）。 */
    public Map<String, Object> selectExamStage(@Param("companyId") Long companyId,
            @Param("positionId") Long positionId, @Param("stageId") Long stageId);

    /** 幂等加入考试场次；已撤销分配会复用原行并递增修订号。 */
    public int upsertScheduleCandidate(Map<String, Object> params);

    public int countActiveScheduleCandidate(@Param("scheduleId") Long scheduleId,
            @Param("candidateId") Long candidateId);

    public int revokeScheduleCandidate(@Param("scheduleId") Long scheduleId,
            @Param("candidateId") Long candidateId);

    public int markScheduleCandidateNotify(Map<String, Object> params);

    // ==================== 笔试通知 ====================

    /** 保存考试安排的通知配置JSON */
    public int updateScheduleNotifyConfig(@Param("scheduleId") Long scheduleId,
            @Param("configJson") String configJson);

    /** 通知对象：该安排已分配且未撤销的候选人（含 sys_user 联系方式） */
    public List<Map<String, Object>> selectNotifyTargets(@Param("companyId") Long companyId,
            @Param("scheduleId") Long scheduleId);

    /** 写入站内笔试通知（t_msg，msg_type=5 笔试通知） */
    public int insertExamNotifyMessage(@Param("receiverId") Long receiverId,
            @Param("title") String title, @Param("content") String content);
}
