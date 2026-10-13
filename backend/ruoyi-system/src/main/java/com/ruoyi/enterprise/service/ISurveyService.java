package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - 满意度调研服务层
 *
 * <p>依据《业务功能分析》UC-17（候选人体验调研与数据分析）。</p>
 *
 * @author enterprise
 */
public interface ISurveyService
{
    /**
     * 调研结果汇总（UC-17）：平均满意度、评分分布、回收明细（含文字反馈）
     */
    public Map<String, Object> getResults(Long userId, Long templateId, String from, String to);

    /**
     * 问卷模板列表（UC-17）
     */
    public List<Map<String, Object>> listTemplates(Long userId);
}
