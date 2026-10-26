package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - 满意度调研服务层
 *
 * <p>依据《业务功能分析》UC-17（候选人体验调研与数据分析）。
 * 所有查询与变更均按登录用户所属企业（t_cmp_binding）做数据隔离。</p>
 *
 * @author enterprise
 */
public interface ISurveyService
{
    /**
     * 调研结果汇总（UC-17）：平均满意度、评分分布、发送与回收统计、回收明细（含文字反馈）
     */
    public Map<String, Object> getResults(Long userId, Long templateId, String from, String to);

    /**
     * 问卷模板列表（UC-17）：平台通用 + 本企业自有；all=true 时含停用模板，否则仅启用模板
     */
    public List<Map<String, Object>> listTemplates(Long userId, Boolean all);

    /** 新增本企业问卷模板 */
    public Map<String, Object> createTemplate(Long userId, Map<String, Object> body);

    /** 修改本企业问卷模板（含触发场景与启停用） */
    public Map<String, Object> updateTemplate(Long userId, Long templateId, Map<String, Object> body);

    /** 启停用本企业问卷模板 */
    public void updateTemplateStatus(Long userId, Long templateId, Integer status);

    /** 删除本企业问卷模板（已产生回收或发送记录时拒绝） */
    public void deleteTemplate(Long userId, Long templateId);

    /** 向指定候选人发送调研问卷，生成匿名链接令牌并落发送记录 */
    public Map<String, Object> send(Long userId, Long candidateUserId, Long templateId);

    /** 候选人按匿名令牌读取问卷填写内容（问卷名称、题目、企业与候选人信息、填写状态） */
    public Map<String, Object> getFillForm(String token);

    /** 候选人按匿名令牌提交问卷作答，写入回收记录并把发送记录标记为已填写 */
    public Map<String, Object> submitFill(String token, Map<String, Object> body);
}
