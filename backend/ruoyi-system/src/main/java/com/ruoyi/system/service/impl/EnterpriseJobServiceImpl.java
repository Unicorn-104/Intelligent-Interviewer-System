package com.ruoyi.system.service.impl;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;
import com.ruoyi.system.service.IEnterpriseJobService;
import com.ruoyi.system.mapper.app.AppCompanyMapper;

/**
 * 企业端岗位管理 服务实现
 *
 * @author ruoyi
 */
@Service
public class EnterpriseJobServiceImpl implements IEnterpriseJobService
{
    @Autowired
    private EnterpriseJobMapper jobMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Autowired
    private AppCompanyMapper companyMapper;

    @Override
    public Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }

    @Override
    public List<Map<String, Object>> selectJobList(Long companyId, String keyword, String dept, Integer status)
    {
        return jobMapper.selectJobList(companyId, keyword, dept, status);
    }

    @Override
    public List<String> selectJobDepartments(Long userId)
    {
        return jobMapper.selectJobDepartments(resolveCompanyId(userId));
    }

    @Override
    @Transactional
    public int changeJobStatus(Long userId, Long posId, Integer status)
    {
        if (status == null || status < 0 || status > 2)
        {
            throw new ServiceException("非法岗位状态");
        }
        Long companyId = resolveCompanyId(userId);
        Integer previous = companyMapper.lockPositionStatus(companyId, posId);
        int changed = jobMapper.updateJobStatus(posId, companyId, status);
        if (changed > 0 && status == 1 && previous != null && previous != 1)
        {
            companyMapper.notifyFollowers(companyId, posId);
        }
        return changed;
    }

    @Override
    @Transactional
    public Map<String, Object> createJob(Long userId, Map<String, Object> form)
    {
        String title = str(form.get("title"));
        if (StringUtils.isEmpty(title))
        {
            throw new ServiceException("岗位名称不能为空");
        }
        java.math.BigDecimal min = decimal(form.get("salaryMin"));
        java.math.BigDecimal max = decimal(form.get("salaryMax"));
        String jdJson = buildJdJson(form);
        int status = form.get("status") == null ? 1 : Integer.parseInt(String.valueOf(form.get("status")));
        Long companyId = resolveCompanyId(userId);
        jobMapper.insertJob(companyId, userId, title, str(form.get("dept")), str(form.get("city")),
                min, max, str(form.get("experience")),
                form.get("education") == null ? 3 : Integer.parseInt(String.valueOf(form.get("education"))),
                form.get("jobType") == null ? 1 : Integer.parseInt(String.valueOf(form.get("jobType"))),
                jdJson, status);
        if (status == 1)
        {
            companyMapper.notifyFollowers(companyId, companyMapper.selectLastInsertedPositionId());
        }
        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("title", title);
        return result;
    }

    @Override
    public Map<String, Object> jobDetail(Long userId, Long posId)
    {
        Map<String, Object> job = jobMapper.selectJobById(posId, resolveCompanyId(userId));
        if (job == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("job", job);
        result.put("funnel", jobMapper.selectJobFunnel(posId));
        result.put("candidates", jobMapper.selectJobCandidates(posId));
        result.put("stages", jobMapper.selectJobStages(posId));
        return result;
    }

    @Override
    public Map<String, Object> workflow(Long userId, Long posId)
    {
        Long companyId = resolveCompanyId(userId);
        if (jobMapper.selectJobById(posId, companyId) == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        Map<String, Object> template = jobMapper.selectTemplateByPos(posId, companyId);
        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("template", template);
        result.put("stages", template == null ? new java.util.ArrayList<>() : jobMapper.selectStagesByTemplate(((Number) template.get("templateId")).longValue()));
        return result;
    }

    @Override
    @Transactional
    public Map<String, Object> saveWorkflow(Long userId, Long posId, String templateName, List<Map<String, Object>> stages)
    {
        Long companyId = resolveCompanyId(userId);
        if (jobMapper.selectJobById(posId, companyId) == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        if (stages == null || stages.isEmpty())
        {
            throw new ServiceException("流程至少需要一个阶段");
        }
        Map<String, Object> template = jobMapper.selectTemplateByPos(posId, companyId);
        Long templateId;
        if (template == null)
        {
            String name = StringUtils.isEmpty(templateName) ? "岗位招聘流程" : templateName;
            jobMapper.insertTemplate(companyId, posId, name);
            templateId = jobMapper.selectLatestTemplateIdByPos(posId);
            jobMapper.bindPosTemplate(posId, companyId, templateId);
        }
        else
        {
            templateId = ((Number) template.get("templateId")).longValue();
            jobMapper.bumpTemplateVersion(templateId);
            if (StringUtils.isNotEmpty(templateName))
            {
                jobMapper.renameTemplate(templateId, templateName);
            }
            jobMapper.deleteStagesByTemplate(templateId);
        }
        int order = 1;
        for (Map<String, Object> s : stages)
        {
            String name = str(s.get("name"));
            if (StringUtils.isEmpty(name))
            {
                throw new ServiceException("阶段名称不能为空");
            }
            int type = s.get("type") == null ? 3 : Integer.parseInt(String.valueOf(s.get("type")));
            int required = Boolean.TRUE.equals(s.get("required")) || "true".equals(String.valueOf(s.get("required"))) ? 1 : 0;
            int threshold = s.get("threshold") == null ? 70 : Integer.parseInt(String.valueOf(s.get("threshold")));
            jobMapper.insertStage(templateId, name, type, order++, required, threshold, buildStageConfig(s));
        }
        Map<String, Object> fresh = jobMapper.selectTemplateByPos(posId, companyId);
        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("templateId", templateId);
        result.put("version", fresh == null ? null : fresh.get("version"));
        return result;
    }

    private String buildStageConfig(Map<String, Object> s)
    {
        StringBuilder sb = new StringBuilder("{");
        sb.append("\"duration\":").append(number(s.get("duration"), 45));
        sb.append(",\"interviewer\":").append(jsonStr(str(s.get("interviewer"))));
        sb.append(",\"target\":").append(jsonStr(str(s.get("target"))));
        sb.append(",\"mode\":").append(jsonStr(str(s.get("mode"))));
        sb.append(",\"skip\":").append(bool(s.get("skip")));
        sb.append(",\"terminate\":").append(bool(s.get("terminate")));
        sb.append("}");
        return sb.toString();
    }

    private String number(Object v, int def)
    {
        if (v == null)
        {
            return String.valueOf(def);
        }
        try
        {
            return String.valueOf(Integer.parseInt(String.valueOf(v)));
        }
        catch (NumberFormatException e)
        {
            return String.valueOf(def);
        }
    }

    private String bool(Object v)
    {
        boolean b = Boolean.TRUE.equals(v) || "true".equalsIgnoreCase(String.valueOf(v));
        return b ? "true" : "false";
    }

    private String str(Object v)
    {
        return v == null ? null : String.valueOf(v);
    }

    private java.math.BigDecimal decimal(Object v)
    {
        if (v == null || StringUtils.isEmpty(String.valueOf(v)))
        {
            return null;
        }
        try
        {
            return new java.math.BigDecimal(String.valueOf(v));
        }
        catch (NumberFormatException e)
        {
            return null;
        }
    }

    private String buildJdJson(Map<String, Object> form)
    {
        StringBuilder sb = new StringBuilder("{");
        Object reqs = form.get("requirements");
        Object resp = form.get("responsibilities");
        Object desc = form.get("description");
        sb.append("\"description\":").append(jsonStr(str(desc)));
        if (reqs instanceof List<?> list && !list.isEmpty())
        {
            sb.append(",\"requirements\":[");
            appendArray(sb, list);
            sb.append("]");
        }
        else if (StringUtils.isNotEmpty(str(reqs)))
        {
            sb.append(",\"requirements\":[").append(jsonStr(String.valueOf(reqs))).append("]");
        }
        if (resp instanceof List<?> list && !list.isEmpty())
        {
            sb.append(",\"responsibilities\":[");
            appendArray(sb, list);
            sb.append("]");
        }
        sb.append("}");
        return sb.toString();
    }

    private void appendArray(StringBuilder sb, List<?> list)
    {
        for (int i = 0; i < list.size(); i++)
        {
            if (i > 0)
            {
                sb.append(",");
            }
            sb.append(jsonStr(String.valueOf(list.get(i))));
        }
    }

    private String jsonStr(String v)
    {
        if (v == null)
        {
            return "null";
        }
        return "\"" + v.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "") + "\"";
    }
}
