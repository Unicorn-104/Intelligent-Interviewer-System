package com.ruoyi.enterprise.mapper;

import java.util.List;
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

    /** 候选人档案 + 用户信息 + 简历基础 */
    public Map<String, Object> selectTalentById(@Param("companyId") Long companyId, @Param("talId") Long talId);

    /** 候选人标签列表 */
    public List<Map<String, Object>> selectTalentTags(@Param("talId") Long talId);

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
