package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.enterprise.mapper.SurveyMapper;
import com.ruoyi.enterprise.service.ISurveyService;

/**
 * 企业端 - 满意度调研服务实现
 *
 * <p>依据《业务功能分析》UC-17：
 * 面试后 24 小时自动发送满意度问卷，采集候选人对流程便捷度、
 * 面试官专业度、系统易用性的评分与文字反馈，供 HR 分析。</p>
 *
 * @author enterprise
 */
@Service
public class SurveyServiceImpl implements ISurveyService
{
    @Autowired
    private SurveyMapper surveyMapper;

    @Override
    public Map<String, Object> getResults(Long userId, Long templateId, String from, String to)
    {
        // 均分与分布（svr_satisfaction_score 为百分制满意度分）
        Map<String, Object> summary = surveyMapper.selectSummary(templateId, from, to);
        long total = summary == null || summary.get("total") == null ? 0
                : Long.parseLong(String.valueOf(summary.get("total")));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("responseCount", total);
        result.put("avgScore", summary == null || summary.get("avgScore") == null ? null
                : round(Double.parseDouble(String.valueOf(summary.get("avgScore")))));
        result.put("distribution", surveyMapper.selectDistribution(templateId, from, to));
        // 回收明细：svr_answers JSON 承载各题答案（含文字反馈），原样返回供前端解析
        List<Map<String, Object>> responses = surveyMapper.selectResponses(templateId, from, to);
        for (Map<String, Object> response : responses)
        {
            response.put("answers", response.get("answers") == null ? null
                    : JSON.parse(String.valueOf(response.get("answers"))));
        }
        result.put("responses", responses);
        return result;
    }

    @Override
    public List<Map<String, Object>> listTemplates(Long userId)
    {
        List<Map<String, Object>> templates = surveyMapper.selectTemplates();
        for (Map<String, Object> template : templates)
        {
            template.put("questions", template.get("questions") == null ? null
                    : JSON.parse(String.valueOf(template.get("questions"))));
        }
        return templates;
    }

    private double round(double value)
    {
        return BigDecimal.valueOf(value).setScale(1, RoundingMode.HALF_UP).doubleValue();
    }
}
