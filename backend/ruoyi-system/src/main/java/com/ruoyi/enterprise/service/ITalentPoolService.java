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
     * 人才库检索（UC-03）：关键词（姓名/电话）+ 标签 + 岗位方向 + 归档来源 + 流程状态 + 分页
     */
    public List<Map<String, Object>> listTalents(Long userId, String keyword, String tag,
            String direction, Integer archiveSource, Integer status, Integer pageNum, Integer pageSize);

    /**
     * 人才库筛选项（岗位方向选项 + 标签选项）
     */
    public Map<String, Object> getTalentOptions(Long userId);

    /**
     * 主动归档 / 取消归档（tal_archive_source：3-主动归档，0-取消）
     */
    public Map<String, Object> archiveTalent(Long userId, Long talId, Boolean archived);

    /**
     * 批量更新候选人流程状态（tal_status），用于候选人管理的状态管理
     */
    public Map<String, Object> updateStatus(Long userId, List<Long> talIds, Integer status);

    /**
     * 一键转投递：为候选人创建投递记录（t_app_record）
     */
    public Map<String, Object> reapplyTalent(Long userId, Long talId, Long positionId);

    /**
     * 落选关怀通知：向选中的候选人批量写入系统消息（t_msg）
     */
    public Map<String, Object> careNotify(Long userId, List<Long> talIds, String title, String content);

    /**
     * 候选人详情（UC-03）：档案 + 标签 + 简历基础信息
     */
    public Map<String, Object> getTalentDetail(Long userId, Long talId);

    /**
     * 简历解析结果（UC-02 步骤4-5）：结构化字段 + 完整度检查
     */
    public Map<String, Object> getTalentResume(Long userId, Long talId);
}
