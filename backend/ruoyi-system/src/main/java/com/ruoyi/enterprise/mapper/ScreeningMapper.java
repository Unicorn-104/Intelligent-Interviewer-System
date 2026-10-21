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

    /** 候选人技能标签（简历解析产物） */
    public List<String> selectCandidateSkills(@Param("talId") Long talId);

    /** 更新匹配度综合评分（UC-05 步骤4 落库） */
    public int updateMatchedScore(@Param("talId") Long talId, @Param("score") Double score);

    /** 筛选任务列表：按岗位聚合流程实例（taskId 即岗位ID） */
    public List<Map<String, Object>> selectTaskList();

    /** 某岗位筛选结果：候选人评分降序（含技能标签串） */
    public List<Map<String, Object>> selectResultsByPosition(@Param("positionId") Long positionId);

    /** 候选人最新推荐报告/招呼语记录（grt_match_points + grt_content） */
    public Map<String, Object> selectGreetingByCandidate(@Param("talId") Long talId);

    /** 更新候选人流程状态（UC-06 复核确认，状态日志由数据库触发器写入） */
    public int updateTalStatus(@Param("talId") Long talId, @Param("status") Integer status);

    /** 某岗位待初筛的投递申请（app_status = 0） */
    public List<Map<String, Object>> selectPendingApplications(@Param("positionId") Long positionId);

    /** 回写投递记录的 AI 初筛结果（评分 + 投递状态：1-初筛通过，2-初筛淘汰） */
    public int updateApplicationScreened(@Param("applicationId") Long applicationId, @Param("score") Double score,
            @Param("status") Integer status);
}
