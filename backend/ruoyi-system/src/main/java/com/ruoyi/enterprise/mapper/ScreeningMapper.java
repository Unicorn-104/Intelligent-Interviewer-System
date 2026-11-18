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

    /** 可参与 AI 初筛的候选人：待分析/已分析投递覆盖 app_status=0(已投递) 与 1(招聘中)，流程实例进行中 */
    public List<Map<String, Object>> selectScreenableCandidates(@Param("positionId") Long positionId);

    /** 候选人技能标签（简历解析产物） */
    public List<String> selectCandidateSkills(@Param("talId") Long talId);

    /** 以下四个方法从企业快照子表读取结构化证据，AI 分析不再读 C-App 表 */
    List<Map<String, Object>> selectSnapshotEducation(@Param("snapshotId") Long snapshotId);
    List<Map<String, Object>> selectSnapshotWork(@Param("snapshotId") Long snapshotId);
    List<Map<String, Object>> selectSnapshotProject(@Param("snapshotId") Long snapshotId);
    List<String> selectSnapshotSkills(@Param("snapshotId") Long snapshotId);
    Map<String, Object> selectSnapshotByApp(@Param("appId") Long appId);

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
    /** 按投递(app_id)精确取最新一条 AI(llm) 分析，重复投递不串用 */
    Map<String, Object> selectAnalysis(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("applicationId") Long applicationId, @Param("talId") Long talId);
    /** 按投递(app_id)精确取最新一条 HR 人工(manual) 评分，不串用其他投递 */
    Map<String, Object> selectManualAnalysis(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("applicationId") Long applicationId, @Param("talId") Long talId);
    Map<String, Object> selectLatestAnalysis(@Param("companyId") Long companyId, @Param("talId") Long talId);
    /** 企业和岗位隔离的增量去重查询，不作为模型输入。 */
    List<Map<String, Object>> selectAnalyzedCandidates(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    int saveAnalysis(Map<String, Object> analysis);
    /** 追加式保存 HR 人工评分 */
    int saveManualAnalysis(Map<String, Object> analysis);
    int initTask(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    int claimTask(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("runId") String runId, @Param("candidateCount") int candidateCount);
    Map<String, Object> selectTaskStatus(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    Map<String, Object> lockTask(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
    int updateTask(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("runId") String runId, @Param("state") String state, @Param("completed") int completed,
            @Param("passed") int passed, @Param("error") String error);

    /** 某岗位待分析/已分析的投递申请（app_status in (0 已投递, 1 招聘中)） */
    public List<Map<String, Object>> selectPendingApplications(@Param("positionId") Long positionId);

    /** 按投递ID回写适配度评分（仅 app_matched_score，绝不写 app_status；仅 0/1 态可写） */
    public int updateApplicationMatchedScore(@Param("applicationId") Long applicationId,
            @Param("score") Double score);

    /** 按岗位 + 候选人只更新投递适配度评分，保留已有 app_status；仅当当前状态在 fromStatuses 内才更新 */
    public int updateApplicationScore(@Param("positionId") Long positionId, @Param("talId") Long talId,
            @Param("score") Double score, @Param("fromStatuses") List<Integer> fromStatuses);

    /** 本企业仍有待分析/已分析投递（app_status in (0,1)）的岗位 */
    public List<Long> selectPendingPositions(@Param("companyId") Long companyId);

    /** 校验候选人是否真实投递过该企业岗位 */
    public int countOwnedApplication(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("talId") Long talId);

    /** 投递记录关联的简历ID（无 AI 分析结果时用于创建人工评分记录） */
    public Long selectApplicationResume(@Param("companyId") Long companyId, @Param("positionId") Long positionId,
            @Param("talId") Long talId);

    /**
     * 按单列主键 asr_id 精确定位回写报告（多版本下禁止按非唯一三元组更新）。
     * 当前无生产调用方，防御性保留；调用前须先取得目标记录 asr_id。
     */
    public int updateAnalysisReport(@Param("id") Long id, @Param("report") String report);
}
