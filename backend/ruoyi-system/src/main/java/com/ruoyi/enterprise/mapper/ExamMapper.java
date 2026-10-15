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

    // ==================== 题库 ====================

    public List<Map<String, Object>> selectQuestionList(@Param("type") Integer type,
            @Param("difficulty") Integer difficulty, @Param("skillTag") String skillTag,
            @Param("keyword") String keyword);

    public Map<String, Object> selectQuestionById(@Param("id") Long id);

    public int insertQuestion(Map<String, Object> params);

    public int selectLastQuestionId();

    public int updateQuestion(Map<String, Object> params);

    public int deleteQuestion(@Param("id") Long id);

    /** 按条件随机抽题（排除已选题目ID） */
    public List<Map<String, Object>> drawQuestions(@Param("type") Integer type,
            @Param("difficulty") Integer difficulty, @Param("skillTag") String skillTag,
            @Param("excludeIds") List<Long> excludeIds, @Param("limit") Integer limit);

    /** 满足抽题条件的可用题目数 */
    public int countDrawQuestions(@Param("type") Integer type, @Param("difficulty") Integer difficulty,
            @Param("skillTag") String skillTag);

    // ==================== 试卷 ====================

    public List<Map<String, Object>> selectPaperList(@Param("companyId") Long companyId,
            @Param("positionId") Long positionId);

    public Map<String, Object> selectPaperById(@Param("companyId") Long companyId, @Param("paperId") Long paperId);

    public List<Map<String, Object>> selectPaperQuestions(@Param("paperId") Long paperId);

    public int insertPaper(Map<String, Object> params);

    public int selectLastPaperId();

    public int updatePaper(Map<String, Object> params);

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

    // ==================== 笔试通知 ====================

    /** 保存考试安排的通知配置JSON */
    public int updateScheduleNotifyConfig(@Param("scheduleId") Long scheduleId,
            @Param("configJson") String configJson);

    /** 通知对象：该安排岗位的全部投递候选人（含 sys_user 联系方式） */
    public List<Map<String, Object>> selectNotifyTargets(@Param("companyId") Long companyId,
            @Param("scheduleId") Long scheduleId);

    /** 写入站内笔试通知（t_msg，msg_type=5 笔试通知） */
    public int insertExamNotifyMessage(@Param("receiverId") Long receiverId,
            @Param("title") String title, @Param("content") String content);
}
