package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - AI 初筛与智能匹配数据层
 *
 * <p>依据《业务功能分析》UC-04/05/06：
 * 岗位技能画像 t_pos_skill、候选人池 t_process_instance + t_tal、
 * 候选人技能 t_res_skill、推荐报告与招呼语 t_greeting_record、
 * 状态变更日志由 t_tal 数据库触发器自动维护。</p>
 *
 * @author enterprise
 */
public interface ScreeningMapper
{
    /** 岗位技能标签（必备技能，UC-04 硬性过滤依据） */
    public List<String> selectPositionSkills(@Param("positionId") Long positionId);

    /** 岗位候选人池（来自流程实例 + 候选人档案） */
    public List<Map<String, Object>> selectCandidatesByPosition(@Param("positionId") Long positionId);

    /** 可参与 AI 初筛的候选人：仅待筛选(app_status=0)且流程实例进行中的投递 */
    public List<Map<String, Object>> selectScreenableCandidates(@Param("positionId") Long positionId);

    /** 候选人技能标签（简历解析产物） */
    public List<String> selectCandidateSkills(@Param("talId") Long talId);

    /** 更新匹配度综合评分（UC-05 步骤4 落库） */
    public int updateMatchedScore(@Param("talId") Long talId, @Param("score") Double score);

    /** 筛选任务列表：按岗位聚合流程实例（taskId 即岗位ID） */
    public List<Map<String, Object>> selectTaskList(@Param("companyId") Long companyId);

    /** 某岗位筛选结果：候选人评分降序（含技能标签串） */
    public List<Map<String, Object>> selectResultsByPosition(@Param("positionId") Long positionId);

    /** 候选人最新推荐报告/招呼语记录（grt_match_points + grt_content） */
    public Map<String, Object> selectGreetingByCandidate(@Param("talId") Long talId);

    Map<String, Object> selectPosition(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    Map<String, Object> selectOwnedCandidate(@Param("companyId") Long companyId, @Param("talId") Long talId);
    List<Map<String, Object>> selectEducationEvidence(@Param("resumeId") Long resumeId);
    List<Map<String, Object>> selectWorkEvidence(@Param("resumeId") Long resumeId);
    List<Map<String, Object>> selectProjectEvidence(@Param("resumeId") Long resumeId);
    Map<String, Object> selectAnalysis(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("talId") Long talId);
    Map<String, Object> selectLatestAnalysis(@Param("companyId") Long companyId, @Param("talId") Long talId);
    /** 企业和岗位隔离的增量去重查询，不作为模型输入。 */
    List<Map<String, Object>> selectAnalyzedCandidates(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    int saveAnalysis(Map<String, Object> analysis);
    int initTask(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    int claimTask(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("runId") String runId, @Param("candidateCount") int candidateCount);
    Map<String, Object> selectTaskStatus(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    Map<String, Object> lockTask(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    int updateTask(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("runId") String runId, @Param("state") String state, @Param("completed") int completed,
            @Param("passed") int passed, @Param("error") String error);

    /** 某岗位待初筛的投递申请（app_status = 0） */
    public List<Map<String, Object>> selectPendingApplications(@Param("positionId") Long positionId);

    /** 回写投递记录的 AI 初筛结果（评分 + 投递状态：1-初筛通过，2-初筛淘汰） */
    public int updateApplicationScreened(@Param("applicationId") Long applicationId, @Param("score") Double score,
            @Param("status") Integer status);

    /** 按岗位 + 候选人回写投递评分与状态（AI 初筛完成、HR 复核共用），仅当当前状态在 fromStatuses 内才更新 */
    public int updateApplicationByCandidate(@Param("positionId") Long positionId, @Param("talId") Long talId,
            @Param("score") Double score, @Param("status") Integer status,
            @Param("fromStatuses") List<Integer> fromStatuses);

    /** 按岗位 + 候选人只更新投递评分，保留已有状态，仅当当前状态在 fromStatuses 内才更新 */
    public int updateApplicationScore(@Param("positionId") Long positionId, @Param("talId") Long talId,
            @Param("score") Double score, @Param("fromStatuses") List<Integer> fromStatuses);

    /** 按岗位 + 候选人只更新投递状态，保留已有评分，仅当当前状态在 fromStatuses 内才更新 */
    public int updateApplicationStatusByCandidate(@Param("positionId") Long positionId, @Param("talId") Long talId,
            @Param("status") Integer status, @Param("fromStatuses") List<Integer> fromStatuses);

    /** 本企业仍有待初筛（app_status = 0）投递的岗位 */
    public List<Long> selectPendingPositions(@Param("companyId") Long companyId);

    /** 流程环节推进时同步投递状态（仅当当前状态在 fromStatuses 内才更新） */
    public int advanceApplicationStatus(@Param("positionId") Long positionId, @Param("talId") Long talId,
            @Param("status") Integer status, @Param("fromStatuses") List<Integer> fromStatuses);

    /** 校验候选人是否真实投递过该企业岗位 */
    public int countOwnedApplication(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("talId") Long talId);

    /** 投递记录关联的简历ID（无 AI 分析结果时用于创建人工评分记录） */
    public Long selectApplicationResume(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("talId") Long talId);

    /** 回写 HR 复核调整后的 AI 分析报告 */
    public int updateAnalysisReport(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("talId") Long talId, @Param("report") String report);
}
