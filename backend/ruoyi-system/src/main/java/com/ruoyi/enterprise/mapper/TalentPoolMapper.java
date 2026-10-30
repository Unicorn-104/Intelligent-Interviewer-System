package com.ruoyi.enterprise.mapper;

import java.util.List;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 人才库数据层
 *
 * <p>依据《业务功能分析》UC-03：t_tal 候选人档案 + t_tal_tag 标签 +
 * t_res_* 结构化简历（UC-02 解析产物）。</p>
 *
 * @author enterprise
 */
public interface TalentPoolMapper
{
    /** 人才库检索列表（关键词/标签/岗位方向/归档来源/流程状态 + 分页） */
    public List<Map<String, Object>> selectTalentList(@Param("companyId") Long companyId,
            @Param("keyword") String keyword, @Param("tag") String tag,
            @Param("direction") String direction, @Param("archiveSource") Integer archiveSource,
            @Param("status") Integer status);

    List<Map<String, Object>> selectFilteredTalentList(@Param("companyId") Long companyId,
            @Param("keyword") String keyword, @Param("tag") String tag,
            @Param("direction") String direction, @Param("archiveSource") Integer archiveSource,
            @Param("status") Integer status, @Param("criteria") TalentSearchCriteria criteria);

    List<String> selectTalentCities(@Param("companyId") Long companyId, @Param("cityType") String cityType);

    /** 岗位方向选项（企业内人才简历去重方向） */
    public List<String> selectTalentDirections(@Param("companyId") Long companyId);

    /** 标签选项（企业内人才标签去重名称） */
    public List<String> selectTalentTagNames(@Param("companyId") Long companyId);

    /** 更新归档来源（3-主动归档，0-取消归档） */
    public int updateArchiveSource(@Param("talId") Long talId, @Param("archiveSource") Integer archiveSource);

    /** 批量更新候选人流程状态（企业隔离） */
    public int updateTalentStatus(@Param("companyId") Long companyId, @Param("talIds") List<Long> talIds,
            @Param("status") Integer status);

    /** 校验岗位归属企业（返回 pos_id 或 null） */
    public Integer selectPositionInCompany(@Param("companyId") Long companyId, @Param("positionId") Long positionId);

    /** 校验候选人是否已投递该岗位（返回 app_id 或 null） */
    public Integer selectApplicationExists(@Param("talId") Long talId, @Param("positionId") Long positionId);

    /** 为候选人创建投递记录（一键转投递） */
    public int insertApplication(@Param("talId") Long talId, @Param("positionId") Long positionId,
            @Param("resumeId") Long resumeId);

    /** 写入落选关怀系统消息（t_msg） */
    public int insertCareMessage(@Param("receiverId") Long receiverId, @Param("title") String title,
            @Param("content") String content);

    /** 批量给本企业候选人打标签返回实际写入条数 */
    public int insertBatchTags(@Param("companyId") Long companyId, @Param("talIds") List<Long> talIds,
            @Param("tagName") String tagName, @Param("source") Integer source);

    /** 候选人档案 + 用户信息 + 简历基础 */
    public Map<String, Object> selectTalentById(@Param("companyId") Long companyId, @Param("talId") Long talId);

    /** 候选人标签列表 */
    public List<Map<String, Object>> selectTalentTags(@Param("talId") Long talId);

    /** 待初筛岗位列表：各岗位下投递状态为待筛选且尚无 AI 匹配评分的候选人数（按人去重） */
    public List<Map<String, Object>> selectUnscreenedPositions(@Param("companyId") Long companyId);

    /** 候选人列表（按投递 t_app_record 一行，状态按投递 + Offer 展示） */
    public List<Map<String, Object>> selectApplicationList(@Param("companyId") Long companyId,
            @Param("positionId") Long positionId, @Param("status") Integer status,
            @Param("talentId") Long talentId);

    /** 本企业有过投递的岗位下拉选项（去重，按岗位ID倒序） */
    public List<Map<String, Object>> selectApplicationPositions(@Param("companyId") Long companyId);

    /** 批量更新投递状态（企业隔离） */
    public int updateApplicationStatus(@Param("companyId") Long companyId,
            @Param("applicationIds") List<Long> applicationIds, @Param("status") Integer status);

    /** 企业下待初筛人选总数（同一人投递多个岗位只算一次） */
    public Integer selectUnscreenedCandidateCount(@Param("companyId") Long companyId);

    /** 待初筛投递人选的检索列表（岗位/关键词 + 分页） */
    public List<Map<String, Object>> selectUnscreenedApplicants(@Param("companyId") Long companyId,
            @Param("positionId") Long positionId, @Param("keyword") String keyword);

    /** 校验岗位归属企业，返回岗位ID；不属于该企业时返回 null */
    public Long selectPositionOfCompany(@Param("positionId") Long positionId, @Param("companyId") Long companyId);

    /** 教育经历列表（UC-02 解析字段） */
    public List<Map<String, Object>> selectEducation(@Param("resumeId") Long resumeId);

    /** 工作经历列表（UC-02 解析字段） */
    public List<Map<String, Object>> selectWork(@Param("resumeId") Long resumeId);

    /** 项目经验列表（UC-02 解析字段） */
    public List<Map<String, Object>> selectProject(@Param("resumeId") Long resumeId);

    /** 技能标签列表（UC-02 解析字段） */
    public List<Map<String, Object>> selectSkill(@Param("resumeId") Long resumeId);

    public int countEducation(@Param("resumeId") Long resumeId);

    public int countWork(@Param("resumeId") Long resumeId);

    public int countProject(@Param("resumeId") Long resumeId);

    public int countSkill(@Param("resumeId") Long resumeId);
}
