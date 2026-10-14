package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - 人才库服务层
 *
 * <p>依据《业务功能分析》UC-03（人才库简历检索与管理）、
 * UC-02（简历投递与智能解析）。</p>
 *
 * @author enterprise
 */
public interface ITalentPoolService
{
    /**
     * 人才库检索（UC-03）：关键词（姓名/电话）+ 标签 + 分页
     */
    public List<Map<String, Object>> listTalents(Long userId, String keyword, String tag,
            Integer pageNum, Integer pageSize);

    /**
     * 候选人详情（UC-03）：档案 + 标签 + 简历基础信息
     */
    public Map<String, Object> getTalentDetail(Long userId, Long talId);

    /**
     * 简历解析结果（UC-02 步骤4-5）：结构化字段 + 完整度检查
     */
    public Map<String, Object> getTalentResume(Long userId, Long talId);
}
