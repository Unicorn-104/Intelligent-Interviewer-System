package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 候选人端 - 在线笔试（我的考试/考试记录/作答快照）数据层
 *
 * <p>对应表：t_exam_schedule、t_exam_record、t_exam_answer。候选人身份经
 * t_tal.tal_user_id 解析为 tal_id，仅可查看/作答自己投递岗位对应的考试安排。</p>
 *
 * @author enterprise
 */
public interface CandidateExamMapper
{
    /** 当前登录用户对应的候选人档案ID（tal_id） */
    public Map<String, Object> selectTalentByUser(@Param("userId") Long userId);

    /** 我的考试列表：投递岗位对应的考试安排 + 本人考试记录状态 */
    public List<Map<String, Object>> selectMyScheduleList(@Param("userId") Long userId);

    /** 指定考试安排（限本人投递岗位），含试卷信息与本人考试记录状态 */
    public Map<String, Object> selectScheduleForCandidate(@Param("userId") Long userId,
            @Param("scheduleId") Long scheduleId);

    /** 新建考试记录（状态1-进行中，开始时间=now） */
    public int insertRecord(@Param("scheduleId") Long scheduleId, @Param("talId") Long talId,
            @Param("deviceInfo") String deviceInfo);

    /** 设备检测阶段新建记录（状态0-未开始，开始时间留空，不计入考试时长） */
    public int insertPrepRecord(@Param("scheduleId") Long scheduleId, @Param("talId") Long talId);

    /** 检测通过后开考：未开始→进行中，开始时间=now */
    public int beginRecord(@Param("recordId") Long recordId);

    public int selectLastRecordId();

    /** 考试记录（限本人），含安排的时长/截止/交卷规则，用于续考与判卷时间线 */
    public Map<String, Object> selectRecordForCandidate(@Param("userId") Long userId,
            @Param("recordId") Long recordId);

    /** 开考快照：写入题目与满分（重复忽略，保证幂等） */
    public int insertAnswerSnapshot(@Param("recordId") Long recordId, @Param("questionId") Long questionId,
            @Param("maxScore") java.math.BigDecimal maxScore);

    /** 记录的题目快照（不含标准答案），按开考顺序返回，含已保存作答 */
    public List<Map<String, Object>> selectRecordQuestions(@Param("recordId") Long recordId);

    /** 保存单题作答内容（仅限快照内题目） */
    public int updateAnswerContent(@Param("recordId") Long recordId, @Param("questionId") Long questionId,
            @Param("content") String content);

    /** 交卷：进行中→已交卷（status=2） */
    public int updateRecordSubmitted(@Param("recordId") Long recordId);

    /** 超时未交卷作废：进行中→已缺考（status=3） */
    public int updateRecordAbandoned(@Param("recordId") Long recordId);
}
