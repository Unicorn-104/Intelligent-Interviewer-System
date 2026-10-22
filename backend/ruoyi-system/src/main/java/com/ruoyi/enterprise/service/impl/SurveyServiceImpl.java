package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.SurveyMapper;
import com.ruoyi.enterprise.service.ISurveyService;

/**
 * 企业端 - 满意度调研服务实现
 *
 * <p>依据《业务功能分析》UC-17：
 * HR 在消息中心选择问卷模板发送给候选人，系统生成匿名填写链接与发送记录，
 * 并汇总回收结果（均分/评分分布/文字反馈）供 HR 分析。
 * 所有数据按登录用户所属企业隔离。</p>
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
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> result = new LinkedHashMap<>();
        if (companyId == null)
        {
            result.put("responseCount", 0L);
            result.put("avgScore", null);
            result.put("distribution", Collections.emptyList());
            result.put("sentCount", 0L);
            result.put("pendingCount", 0L);
            result.put("responses", Collections.emptyList());
            result.put("dispatches", Collections.emptyList());
            return result;
        }
        // 回收汇总（svr_satisfaction_score 为 5 分制满意度分）
        Map<String, Object> summary = surveyMapper.selectSummary(companyId, templateId, from, to);
        result.put("responseCount", toLong(summary == null ? null : summary.get("total")));
        result.put("avgScore", summary == null || summary.get("avgScore") == null ? null
                : round(Double.parseDouble(String.valueOf(summary.get("avgScore")))));
        result.put("distribution", surveyMapper.selectDistribution(companyId, templateId, from, to));
        // 发送与待填写统计（回收率 = 回收量 / 发送量）
        Map<String, Object> dispatchSummary = surveyMapper.selectDispatchSummary(companyId, templateId, from, to);
        result.put("sentCount", toLong(dispatchSummary == null ? null : dispatchSummary.get("sentTotal")));
        result.put("pendingCount", toLong(dispatchSummary == null ? null : dispatchSummary.get("pendingTotal")));
        // 回收明细：svr_answers JSON 承载各题答案（含文字反馈），原样返回供前端解析
        List<Map<String, Object>> responses = surveyMapper.selectResponses(companyId, templateId, from, to);
        for (Map<String, Object> response : responses)
        {
            response.put("answers", response.get("answers") == null ? null
                    : JSON.parse(String.valueOf(response.get("answers"))));
        }
        result.put("responses", responses);
        result.put("dispatches", surveyMapper.selectDispatches(companyId, templateId, from, to));
        return result;
    }

    @Override
    public List<Map<String, Object>> listTemplates(Long userId, Boolean all)
    {
        Long companyId = resolveCompanyId(userId);
        if (companyId == null)
        {
            return Collections.emptyList();
        }
        Integer status = Boolean.TRUE.equals(all) ? null : 1;
        List<Map<String, Object>> templates = surveyMapper.selectTemplates(companyId, status);
        for (Map<String, Object> template : templates)
        {
            template.put("questions", template.get("questions") == null ? null
                    : JSON.parse(String.valueOf(template.get("questions"))));
        }
        return templates;
    }

    @Override
    public Map<String, Object> createTemplate(Long userId, Map<String, Object> body)
    {
        Long companyId = resolveCompanyId(userId);
        if (companyId == null)
        {
            throw new ServiceException("未绑定企业，无法配置问卷");
        }
        String name = requireName(body);
        Integer triggerScene = requireTriggerScene(body);
        String questions = requireQuestions(body);
        Integer status = body.get("status") == null ? 1 : toInt(body.get("status"));
        if (status != 0 && status != 1)
        {
            throw new ServiceException("状态取值不合法");
        }
        Map<String, Object> template = new LinkedHashMap<>();
        template.put("name", name);
        template.put("triggerScene", triggerScene);
        template.put("companyId", companyId);
        template.put("questions", questions);
        template.put("status", status);
        surveyMapper.insertTemplate(template);
        Long templateId = toLong(template.get("templateId"));
        Map<String, Object> created = new LinkedHashMap<>();
        created.put("templateId", templateId);
        created.put("name", name);
        created.put("triggerScene", triggerScene);
        created.put("questions", JSON.parse(questions));
        created.put("status", status);
        return created;
    }

    @Override
    public Map<String, Object> updateTemplate(Long userId, Long templateId, Map<String, Object> body)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> existing = requireOwnTemplate(companyId, templateId);
        String name = requireName(body);
        Integer triggerScene = requireTriggerScene(body);
        String questions = requireQuestions(body);
        Integer status = body.get("status") == null ? toInt(existing.get("status")) : toInt(body.get("status"));
        if (status != 0 && status != 1)
        {
            throw new ServiceException("状态取值不合法");
        }
        Map<String, Object> template = new LinkedHashMap<>();
        template.put("templateId", templateId);
        template.put("name", name);
        template.put("triggerScene", triggerScene);
        template.put("questions", questions);
        template.put("status", status);
        surveyMapper.updateTemplate(template);
        Map<String, Object> updated = new LinkedHashMap<>();
        updated.put("templateId", templateId);
        updated.put("name", name);
        updated.put("triggerScene", triggerScene);
        updated.put("questions", JSON.parse(questions));
        updated.put("status", status);
        return updated;
    }

    @Override
    public void updateTemplateStatus(Long userId, Long templateId, Integer status)
    {
        if (status == null || (status != 0 && status != 1))
        {
            throw new ServiceException("状态取值不合法");
        }
        Long companyId = resolveCompanyId(userId);
        requireOwnTemplate(companyId, templateId);
        surveyMapper.updateTemplateStatus(templateId, status);
    }

    @Override
    public void deleteTemplate(Long userId, Long templateId)
    {
        Long companyId = resolveCompanyId(userId);
        requireOwnTemplate(companyId, templateId);
        if (surveyMapper.countResponsesByTemplate(templateId) > 0
                || surveyMapper.countDispatchesByTemplate(templateId) > 0)
        {
            throw new ServiceException("该模板已产生发送或回收记录，无法删除");
        }
        surveyMapper.deleteTemplate(templateId);
    }

    @Override
    public Map<String, Object> send(Long userId, Long candidateUserId, Long templateId)
    {
        Long companyId = resolveCompanyId(userId);
        if (companyId == null)
        {
            throw new ServiceException("未绑定企业，无法发送问卷");
        }
        if (candidateUserId == null || templateId == null)
        {
            throw new ServiceException("参数不完整");
        }
        Map<String, Object> candidate = surveyMapper.selectCandidateByUser(candidateUserId, companyId);
        if (candidate == null || candidate.get("candidateId") == null)
        {
            throw new ServiceException("候选人不存在或无权访问");
        }
        Map<String, Object> template = surveyMapper.selectTemplateById(templateId);
        if (template == null || !isVisible(template, companyId))
        {
            throw new ServiceException("模板不存在或无权访问");
        }
        if (toInt(template.get("status")) != 1)
        {
            throw new ServiceException("该问卷模板未启用，无法发送");
        }
        Long candidateId = toLong(candidate.get("candidateId"));
        String token = UUID.randomUUID().toString().replace("-", "");
        Map<String, Object> dispatch = new LinkedHashMap<>();
        dispatch.put("templateId", templateId);
        dispatch.put("candidateId", candidateId);
        dispatch.put("companyId", companyId);
        dispatch.put("sentBy", userId);
        dispatch.put("token", token);
        surveyMapper.insertDispatch(dispatch);
        Map<String, Object> sent = new LinkedHashMap<>();
        sent.put("token", token);
        sent.put("templateId", templateId);
        sent.put("templateName", template.get("name"));
        sent.put("candidateId", candidateId);
        sent.put("candidateName", candidate.get("candidateName"));
        return sent;
    }

    /** 解析当前登录用户所属企业ID */
    private Long resolveCompanyId(Long userId)
    {
        if (userId == null)
        {
            return null;
        }
        return surveyMapper.selectCompanyIdByUser(userId);
    }

    /** 校验模板存在且属于本企业（平台通用模板不允许企业修改） */
    private Map<String, Object> requireOwnTemplate(Long companyId, Long templateId)
    {
        Map<String, Object> template = templateId == null ? null : surveyMapper.selectTemplateById(templateId);
        if (template == null || template.get("companyId") == null
                || companyId == null || !companyId.equals(toLong(template.get("companyId"))))
        {
            throw new ServiceException("模板不存在或无权访问");
        }
        return template;
    }

    /** 模板是否对当前企业可见：平台通用（无归属）或本企业自有 */
    private boolean isVisible(Map<String, Object> template, Long companyId)
    {
        Object owner = template.get("companyId");
        return owner == null || companyId.equals(toLong(owner));
    }

    private String requireName(Map<String, Object> body)
    {
        String name = body.get("name") == null ? "" : String.valueOf(body.get("name")).trim();
        if (name.isEmpty())
        {
            throw new ServiceException("问卷名称不能为空");
        }
        if (name.length() > 50)
        {
            throw new ServiceException("问卷名称不能超过50个字符");
        }
        return name;
    }

    private Integer requireTriggerScene(Map<String, Object> body)
    {
        Integer scene = body.get("triggerScene") == null ? null : toInt(body.get("triggerScene"));
        if (scene == null || scene < 1 || scene > 5)
        {
            throw new ServiceException("触发场景取值不合法");
        }
        return scene;
    }

    private String requireQuestions(Map<String, Object> body)
    {
        Object raw = body.get("questions");
        String text = raw == null ? "" : String.valueOf(raw).trim();
        if (text.isEmpty())
        {
            throw new ServiceException("问卷题目不能为空");
        }
        JSONArray array;
        try
        {
            array = JSON.parseArray(text);
        }
        catch (Exception e)
        {
            throw new ServiceException("问卷题目格式不合法");
        }
        if (array == null || array.isEmpty())
        {
            throw new ServiceException("问卷题目不能为空");
        }
        return array.toJSONString();
    }

    private long toLong(Object value)
    {
        return value == null ? 0L : Long.parseLong(String.valueOf(value));
    }

    private int toInt(Object value)
    {
        return value == null ? 0 : Integer.parseInt(String.valueOf(value));
    }

    private double round(double value)
    {
        return BigDecimal.valueOf(value).setScale(1, RoundingMode.HALF_UP).doubleValue();
    }
}
