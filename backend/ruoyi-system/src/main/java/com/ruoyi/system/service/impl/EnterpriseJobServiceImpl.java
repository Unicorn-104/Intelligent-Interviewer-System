package com.ruoyi.system.service.impl;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.constant.ErrorCode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.mapper.EnterpriseJdMapper;
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
    private static final Logger log = LoggerFactory.getLogger(EnterpriseJobServiceImpl.class);

    @Autowired
    private EnterpriseJobMapper jobMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Autowired
    private EnterpriseJdMapper jdMapper;

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
    public Map<String, Object> publishingOptions(Long userId)
    {
        Map<String, Object> company = publishingCompany(userId);
        Map<String, Object> options = new LinkedHashMap<>();
        options.put("company", company);
        options.put("departments", jobMapper.selectJobDepartments(((Number) company.get("id")).longValue()));
        return options;
    }

    private Map<String, Object> publishingCompany(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        // Keep the existing administrator demo-company convention, but never
        // publish an unbound ordinary user's job into somebody else's company.
        if (companyId == null && SecurityUtils.isAdmin(userId))
        {
            companyId = 1L;
        }
        if (companyId == null)
        {
            throw new ServiceException("请先完成企业绑定并通过审核，再发布岗位", ErrorCode.FORBIDDEN);
        }
        Map<String, Object> company = jobMapper.selectPublishingCompany(companyId);
        if (company == null || company.get("id") == null)
        {
            throw new ServiceException("所属企业不存在或已停用，暂时无法发布岗位", ErrorCode.FORBIDDEN);
        }
        return company;
    }

    @Override
    @Transactional
    public Map<String, Object> createJob(Long userId, Map<String, Object> form)
    {
        if (form == null)
        {
            throw new ServiceException("请填写岗位信息", ErrorCode.BAD_REQUEST);
        }
        Map<String, Object> company = publishingCompany(userId);
        Long companyId = ((Number) company.get("id")).longValue();
        List<PositionSkill> skills = positionSkills(form.get("skills"));
        Map<String, Object> job = validatedJob(form, Map.of());
        job.put("companyId", companyId);
        job.put("publisherId", userId);
        int status = choice(form.get("status"), 1, 0, 2, "岗位状态");
        job.put("status", status);
        if (jobMapper.insertJob(job) != 1 || job.get("posId") == null)
        {
            throw new ServiceException("岗位发布失败，请稍后重试");
        }
        Long positionId = ((Number) job.get("posId")).longValue();
        for (PositionSkill skill : skills)
        {
            if (jdMapper.insertPositionSkill(positionId, skill.name(), skill.required()) != 1)
            {
                throw new ServiceException("岗位技能保存失败，请稍后重试");
            }
        }
        if (status == 1)
        {
            companyMapper.notifyFollowers(companyId, positionId);
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("posId", positionId);
        result.put("title", job.get("title"));
        result.put("status", job.get("status"));
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> updateJob(Long userId, Long posId, Map<String, Object> form)
    {
        if (form == null || posId == null || posId <= 0)
        {
            throw new ServiceException("请填写有效的岗位信息", ErrorCode.BAD_REQUEST);
        }
        Long companyId = ((Number) publishingCompany(userId).get("id")).longValue();
        Map<String, Object> existing = jobMapper.selectJobForUpdate(posId, companyId);
        if (existing == null)
        {
            throw new ServiceException("岗位不存在或无权修改", ErrorCode.FORBIDDEN);
        }
        Map<String, Object> existingJd;
        try
        {
            String json = str(existing.get("jdJson"));
            existingJd = StringUtils.isEmpty(json) ? new LinkedHashMap<>() : JSON.parseObject(json);
            if (existingJd == null) throw new IllegalArgumentException();
        }
        catch (RuntimeException error)
        {
            throw new ServiceException("原岗位描述格式异常，请先核对岗位数据");
        }
        Map<String, Object> job = validatedJob(form, existingJd);
        List<PositionSkill> skills = form.containsKey("skills") ? positionSkills(form.get("skills")) : null;
        job.put("posId", posId);
        job.put("companyId", companyId);
        if (jobMapper.updateJob(job) != 1)
        {
            throw new ServiceException("岗位保存失败，请刷新后重试");
        }
        if (skills != null)
        {
            jdMapper.deletePositionSkills(posId);
            for (PositionSkill skill : skills)
            {
                if (jdMapper.insertPositionSkill(posId, skill.name(), skill.required()) != 1)
                {
                    throw new ServiceException("岗位技能保存失败，请稍后重试");
                }
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("posId", posId);
        result.put("title", job.get("title"));
        result.put("status", existing.get("status"));
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> duplicateJob(Long userId, Long posId)
    {
        Map<String, Object> source = jobMapper.selectJobById(posId, resolveCompanyId(userId));
        if (source == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        Map<String, Object> form = new LinkedHashMap<>();
        String title = str(source.get("title")) + "（副本）";
        form.put("title", title.length() > 100 ? title.substring(0, 100) : title);
        form.put("dept", source.get("dept"));
        form.put("city", source.get("city"));
        form.put("experience", source.get("experience"));
        form.put("salaryMin", source.get("salaryMin"));
        form.put("salaryMax", source.get("salaryMax"));
        form.put("education", source.get("education"));
        form.put("jobType", source.get("jobType"));
        Map<String, Object> jd = new LinkedHashMap<>();
        String jdJson = str(source.get("jdJson"));
        if (StringUtils.isNotEmpty(jdJson))
        {
            Map<String, Object> parsed = JSON.parseObject(jdJson);
            if (parsed != null)
            {
                jd = parsed;
            }
        }
        for (String key : List.of("description", "responsibilities", "requirements"))
        {
            if (jd.get(key) != null && !String.valueOf(jd.get(key)).isEmpty())
            {
                form.put(key, jd.get(key));
            }
        }
        List<Map<String, Object>> skills = new ArrayList<>();
        for (Map<String, Object> skill : jdMapper.selectPositionSkills(posId))
        {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("name", skill.get("name"));
            row.put("required", skill.get("required"));
            skills.add(row);
        }
        form.put("skills", skills);
        // 副本强制保存为草稿，避免直接进入在招状态
        form.put("status", 0);
        Map<String, Object> result = createJob(userId, form);
        result.put("sourcePosId", posId);
        result.put("message", "已复制为草稿岗位，请核对后发布");
        return result;
    }

    private Map<String, Object> validatedJob(Map<String, Object> form, Map<String, Object> existingJd)
    {
        Map<String, Object> job = new LinkedHashMap<>();
        job.put("title", requiredText(form.get("title"), "岗位名称", 100));
        job.put("dept", requiredText(form.get("dept"), "所属部门", 50));
        job.put("city", requiredText(form.get("city"), "工作城市", 50));
        String experience = form.get("experience") == null ? "经验不限"
                : requiredText(form.get("experience"), "经验要求", 20);
        job.put("experience", experience);
        BigDecimal min = salary(form.get("salaryMin"));
        BigDecimal max = salary(form.get("salaryMax"));
        if ((min == null) != (max == null) || (min != null && min.compareTo(max) > 0))
        {
            throw new ServiceException("请填写完整薪资范围，且最高月薪不得低于最低月薪", ErrorCode.BAD_REQUEST);
        }
        job.put("salaryMin", min);
        job.put("salaryMax", max);
        job.put("education", choice(form.get("education"), null, 1, 5, "学历要求"));
        job.put("jobType", choice(form.get("jobType"), 1, 1, 3, "工作性质"));
        Map<String, Object> jd = new LinkedHashMap<>(existingJd);
        if (form.containsKey("description"))
        {
            jd.put("description", str(form.get("description")));
        }
        jd.put("responsibilities", jobLines(form.get("responsibilities"), "工作职责"));
        jd.put("requirements", jobLines(form.get("requirements"), "任职要求"));
        job.put("jdJson", JSON.toJSONString(jd));
        return job;
    }

    @Override
    @Transactional
    public Map<String, Object> deleteDraftJob(Long userId, Long posId)
    {
        if (posId == null)
        {
            throw new ServiceException("请选择要删除的岗位", ErrorCode.BAD_REQUEST);
        }
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> job = jobMapper.selectJobById(posId, companyId);
        if (job == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        // 显式清理无外键约束、数据库级联覆盖不到的业务数据，避免残留孤儿记录
        jobMapper.deleteAiAnalysisByPosition(posId);
        jobMapper.deleteScreeningResultByPosition(posId);
        jobMapper.deleteScreeningTaskByPosition(posId);
        jobMapper.deleteRescheduleRequestsByPosition(posId);
        jobMapper.deleteInterviewMeetingStatesByPosition(posId);
        jobMapper.deleteInterviewParticipantStatesByPosition(posId);
        jobMapper.deleteInterviewCopilotsByPosition(posId);
        // 人才档案属于公司人才池，仅解除与本岗位流程实例/笔试记录的关联，不删除档案本身
        jobMapper.detachTalentFromPosition(posId);
        try
        {
            // 岗位技能关联与岗位本体显式删除；投递、流程实例、预约、面试、笔试、Offer
            // 等业务数据由数据库外键 ON DELETE CASCADE 级联删除
            jdMapper.deletePositionSkills(posId);
            if (jobMapper.deleteJob(posId, companyId) != 1)
            {
                throw new ServiceException("岗位删除失败，请稍后重试");
            }
        }
        catch (DataIntegrityViolationException e)
        {
            // 删除时仍有未知外键引用则兜底保护，事务回滚保证前置清理不被误删
            throw new ServiceException("该岗位已有关联的业务数据，无法删除");
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("posId", posId);
        result.put("title", job.get("title"));
        return result;
    }

    private record PositionSkill(String name, Integer required) { }

    private List<PositionSkill> positionSkills(Object value)
    {
        if (value == null)
        {
            return List.of();
        }
        if (!(value instanceof List<?> source))
        {
            throw new ServiceException("技能标签须为数组", ErrorCode.BAD_REQUEST);
        }
        Map<String, PositionSkill> skills = new LinkedHashMap<>();
        for (Object item : source)
        {
            String name;
            Integer required;
            if (item instanceof String text)
            {
                name = requiredText(text, "技能名称", 50);
                required = 1;
            }
            else if (item instanceof Map<?, ?> entry)
            {
                name = requiredText(entry.get("name"), "技能名称", 50);
                required = entry.containsKey("required")
                        ? choice(entry.get("required"), null, 0, 1, "技能必备标识") : Integer.valueOf(1);
            }
            else
            {
                throw new ServiceException("技能标签须为名称字符串或包含name的对象", ErrorCode.BAD_REQUEST);
            }
            String key = name.toLowerCase(Locale.ROOT);
            PositionSkill previous = skills.get(key);
            if (previous == null)
            {
                skills.put(key, new PositionSkill(name, required));
            }
            else if (Integer.valueOf(1).equals(required)
                    || previous.required() == null && required != null)
            {
                skills.put(key, new PositionSkill(previous.name(), required));
            }
        }
        return new ArrayList<>(skills.values());
    }

    private String requiredText(Object value, String label, int maxLength)
    {
        if (!(value instanceof String) || ((String) value).trim().isEmpty())
        {
            throw new ServiceException("请填写" + label, ErrorCode.BAD_REQUEST);
        }
        String text = ((String) value).trim();
        if (text.length() > maxLength)
        {
            throw new ServiceException(label + "最多" + maxLength + "个字符", ErrorCode.BAD_REQUEST);
        }
        return text;
    }

    private Integer choice(Object value, Integer fallback, int min, int max, String label)
    {
        if (value == null)
        {
            return fallback;
        }
        try
        {
            int number = new BigDecimal(String.valueOf(value)).intValueExact();
            if (number >= min && number <= max)
            {
                return number;
            }
        }
        catch (NumberFormatException | ArithmeticException ignored)
        {
        }
        throw new ServiceException(label + "无效", ErrorCode.BAD_REQUEST);
    }

    private BigDecimal salary(Object value)
    {
        if (value == null)
        {
            return null;
        }
        try
        {
            BigDecimal amount = new BigDecimal(String.valueOf(value));
            if (amount.signum() > 0 && amount.compareTo(new BigDecimal("100000000")) < 0
                    && amount.stripTrailingZeros().scale() <= 2)
            {
                return amount;
            }
        }
        catch (NumberFormatException ignored)
        {
        }
        throw new ServiceException("月薪须为大于0且小于1亿元的金额，最多两位小数", ErrorCode.BAD_REQUEST);
    }

    private List<String> jobLines(Object value, String label)
    {
        List<?> source = value instanceof String text ? List.of(text.split("\\R"))
                : value instanceof List<?> items ? items : List.of();
        if (source.isEmpty() || source.size() > 30)
        {
            throw new ServiceException(label + "须填写1至30条", ErrorCode.BAD_REQUEST);
        }
        List<String> lines = new ArrayList<>();
        for (Object item : source)
        {
            lines.add(requiredText(item, label + "条目", 1000));
        }
        if (String.join("\n", lines).length() > 10000)
        {
            throw new ServiceException(label + "总长度不能超过10000个字符", ErrorCode.BAD_REQUEST);
        }
        return lines;
    }

    @Override
    @Transactional
    public Map<String, Object> jobDetail(Long userId, Long posId)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> job = jobMapper.selectJobById(posId, companyId);
        if (job == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        repairMissingProcessInstances(companyId, posId);
        Map<String, Object> result = new java.util.LinkedHashMap<>();
        result.put("job", job);
        result.put("skills", jdMapper.selectPositionSkills(posId));
        result.put("funnel", jobMapper.selectJobFunnel(posId));
        result.put("candidates", jobMapper.selectJobCandidates(posId));
        result.put("stages", jobMapper.selectJobStages(posId));
        return result;
    }

    /**
     * 历史投递兜底：漏斗与候选人列表以流程实例为来源，为缺实例的投递记录补建实例。
     * 单条失败只记录告警不阻断详情页，避免个别脏数据影响整个岗位查看。
     */
    private void repairMissingProcessInstances(Long companyId, Long posId)
    {
        for (Map<String, Object> application : jobMapper.selectApplicationsMissingInstance(posId))
        {
            Object candidateValue = application.get("candidateId");
            if (candidateValue == null)
            {
                continue;
            }
            Long candidateId = Long.valueOf(String.valueOf(candidateValue));
            try
            {
                ensureProcessInstance(companyId, candidateId, posId);
            }
            catch (ServiceException error)
            {
                log.warn("补建投递流程实例失败 positionId={} candidateId={} reason={}", posId, candidateId, error.getMessage());
            }
        }
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

    @Override
    @Transactional
    public Long ensureProcessInstance(Long companyId, Long candidateId, Long positionId)
    {
        if (companyId == null || companyId <= 0 || candidateId == null || candidateId <= 0 || positionId == null || positionId <= 0)
        {
            throw new ServiceException("投递流程参数无效");
        }
        // 锁岗位行，避免并发投递重复建模板/实例
        Map<String, Object> job = jobMapper.selectJobForUpdate(positionId, companyId);
        if (job == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        Map<String, Object> existing = jobMapper.selectProcessInstance(candidateId, positionId);
        if (existing != null)
        {
            return ((Number) existing.get("pinId")).longValue();
        }
        Long templateId = job.get("templateId") == null ? null : Long.valueOf(String.valueOf(job.get("templateId")));
        if (templateId == null)
        {
            // 岗位尚未配置招聘流程时建空模板并绑定，保证实例模板外键成立；
            // 企业后续编辑流程会走版本+1 重建阶段的既有逻辑。
            jobMapper.insertTemplate(companyId, positionId, "岗位招聘流程");
            templateId = jobMapper.selectLatestTemplateIdByPos(positionId);
            jobMapper.bindPosTemplate(positionId, companyId, templateId);
        }
        Map<String, Object> instance = new LinkedHashMap<>();
        instance.put("candidateId", candidateId);
        instance.put("positionId", positionId);
        instance.put("templateId", templateId);
        instance.put("stageId", jobMapper.selectFirstStageIdByPosition(positionId));
        if (jobMapper.insertProcessInstance(instance) != 1 || instance.get("pinId") == null)
        {
            throw new ServiceException("投递流程实例创建失败，请稍后重试");
        }
        Long pinId = ((Number) instance.get("pinId")).longValue();
        jobMapper.updateApplicationInstance(candidateId, positionId, pinId);
        jobMapper.updateTalentInstanceIfAbsent(candidateId, pinId);
        return pinId;
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

    private String jsonStr(String v)
    {
        if (v == null)
        {
            return "null";
        }
        return "\"" + v.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "") + "\"";
    }
}
