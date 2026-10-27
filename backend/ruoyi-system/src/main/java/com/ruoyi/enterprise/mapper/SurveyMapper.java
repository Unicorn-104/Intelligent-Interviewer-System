package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 满意度调研数据层
 *
 * <p>依据《业务功能分析》UC-17：
 * 问卷模板 t_survey_template（svt_questions JSON + svt_company_id 企业隔离）、
 * 回收记录 t_survey_response（svr_answers JSON + 满意度分）、
 * 调研发送记录 t_survey_dispatch。</p>
 *
 * @author enterprise
 */
public interface SurveyMapper
{
    /** 解析当前登录用户所属企业ID */
    public Long selectCompanyIdByUser(@Param("userId") Long userId);

    /** 汇总：回收量/平均满意度（按企业隔离） */
    public Map<String, Object> selectSummary(@Param("companyId") Long companyId,
            @Param("templateId") Long templateId, @Param("from") String from, @Param("to") String to);

    /** 评分分布（按满意度分档聚合，按企业隔离） */
    public List<Map<String, Object>> selectDistribution(@Param("companyId") Long companyId,
            @Param("templateId") Long templateId, @Param("from") String from, @Param("to") String to);

    /** 回收明细（含候选人信息与答案 JSON，按企业隔离） */
    public List<Map<String, Object>> selectResponses(@Param("companyId") Long companyId,
            @Param("templateId") Long templateId, @Param("from") String from, @Param("to") String to);

    /** 调研发送汇总：已发送量/待填写量（按企业隔离） */
    public Map<String, Object> selectDispatchSummary(@Param("companyId") Long companyId,
            @Param("templateId") Long templateId, @Param("from") String from, @Param("to") String to);

    /** 发送记录明细（按企业隔离） */
    public List<Map<String, Object>> selectDispatches(@Param("companyId") Long companyId,
            @Param("templateId") Long templateId, @Param("from") String from, @Param("to") String to);

    /** 问卷模板列表（可见范围：平台通用 svt_company_id 为空 + 本企业自有） */
    public List<Map<String, Object>> selectTemplates(@Param("companyId") Long companyId,
            @Param("status") Integer status);

    /** 单个模板（用于归属校验） */
    public Map<String, Object> selectTemplateById(@Param("templateId") Long templateId);

    /** 新增问卷模板 */
    public int insertTemplate(Map<String, Object> template);

    /** 更新问卷模板 */
    public int updateTemplate(Map<String, Object> template);

    /** 更新模板状态（启停用） */
    public int updateTemplateStatus(@Param("templateId") Long templateId, @Param("status") Integer status);

    /** 删除问卷模板 */
    public int deleteTemplate(@Param("templateId") Long templateId);

    /** 模板的回收记录数 */
    public int countResponsesByTemplate(@Param("templateId") Long templateId);

    /** 模板的发送记录数 */
    public int countDispatchesByTemplate(@Param("templateId") Long templateId);

    /** 候选人基础信息（按用户ID + 企业解析 tal_id） */
    public Map<String, Object> selectCandidateByUser(@Param("userId") Long userId,
            @Param("companyId") Long companyId);

    /** 新增调研发送记录 */
    public int insertDispatch(Map<String, Object> dispatch);

    /** 按匿名填写令牌查询发送记录（含模板题目、候选人与企业信息，用于候选人填写页） */
    public Map<String, Object> selectDispatchByToken(@Param("token") String token);

    /** 新增调研回收记录 */
    public int insertResponse(Map<String, Object> response);

    /** 标记发送记录为已填写 */
    public int markDispatchSubmitted(@Param("dispatchId") Long dispatchId);
}
