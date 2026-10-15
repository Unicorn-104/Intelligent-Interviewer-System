package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 满意度调研数据层
 *
 * <p>依据《业务功能分析》UC-17：
 * 问卷模板 t_survey_template（svt_questions JSON）、
 * 回收记录 t_survey_response（svr_answers JSON + 满意度分）。</p>
 *
 * @author enterprise
 */
public interface SurveyMapper
{
    /** 汇总：回收量/平均满意度 */
    public Map<String, Object> selectSummary(@Param("templateId") Long templateId,
            @Param("from") String from, @Param("to") String to);

    /** 评分分布（按满意度分档聚合） */
    public List<Map<String, Object>> selectDistribution(@Param("templateId") Long templateId,
            @Param("from") String from, @Param("to") String to);

    /** 回收明细（含候选人信息与答案 JSON） */
    public List<Map<String, Object>> selectResponses(@Param("templateId") Long templateId,
            @Param("from") String from, @Param("to") String to);

    /** 问卷模板列表 */
    public List<Map<String, Object>> selectTemplates();
}
