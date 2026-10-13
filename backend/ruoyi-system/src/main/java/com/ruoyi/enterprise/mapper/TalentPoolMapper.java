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
    /** 人才库检索列表（关键词/标签 + 分页） */
    public List<Map<String, Object>> selectTalentList(@Param("companyId") Long companyId,
            @Param("keyword") String keyword, @Param("tag") String tag);

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
