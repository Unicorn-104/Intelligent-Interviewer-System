package com.ruoyi.enterprise.service;

import java.util.Map;

/**
 * 企业端 - 岗位画像（JD Profile）服务层
 *
 * <p>依据《业务功能分析》UC-01（发布岗位并生成 JD 画像）：
 * 解析 JD 文本生成结构化岗位画像，供 AI 筛选模块作为匹配标尺。</p>
 *
 * @author enterprise
 */
public interface IEnterpriseJdService
{
    /**
     * 解析 JD 文本生成岗位画像（UC-01）
     * <p>提取学历、年限、技能标签等硬性指标与软性要求，
     * 快照写入 t_pos.pos_jd_json，技能标签同步 t_pos_skill（先删后插保持幂等）。</p>
     *
     * @param positionId 岗位ID
     * @param jdText JD 原始文本
     * @return 结构化岗位画像
     */
    public Map<String, Object> parseJd(Long positionId, String jdText);

    /**
     * 仅解析 JD 文本，不写库（发布/编辑岗位表单的即时解析）
     *
     * @param jdText JD 原始文本
     * @return 结构化岗位画像
     */
    public Map<String, Object> analyzeJd(String jdText);

    /**
     * 查看岗位画像（UC-01）
     *
     * @param positionId 岗位ID
     * @return 岗位基础信息 + 画像快照 + 技能标签列表
     */
    public Map<String, Object> getJdProfile(Long positionId);
}
