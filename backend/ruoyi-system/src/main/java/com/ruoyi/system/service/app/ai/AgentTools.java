package com.ruoyi.system.service.app.ai;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.agent.AgentApplicationQuery;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.service.agent.IAgentApplicationService;
import com.ruoyi.system.service.agent.IAgentJobService;
import com.ruoyi.system.service.app.IAppResumeService;
import org.springframework.stereotype.Component;

/** Read-only allowlisted tools. Identity is supplied by the server on every invocation. */
@Component
public class AgentTools
{
    private final IAppResumeService resumes;
    private final IAgentJobService jobs;
    private final IAgentApplicationService applications;
    private final ObjectMapper json = new ObjectMapper();

    public AgentTools(IAppResumeService resumes, IAgentJobService jobs, IAgentApplicationService applications)
    {
        this.resumes = resumes;
        this.jobs = jobs;
        this.applications = applications;
    }

    public Map<String, Object> selectedContext(Long userId, Long resumeId, Long applicationId, String action)
    {
        if (userId == null || userId <= 0) throw new ServiceException("请先登录", 401);
        var data = fields("action", action, "resumeId", resumeId);
        if (applicationId == null && ("chat".equals(action) || "writing_polish".equals(action))) return data;
        if (applicationId != null)
        {
            var application = applications.selectApplication(userId, applicationId);
            Long appliedResume = application.getResumeId();
            if (appliedResume == null || appliedResume <= 0)
                throw new ServiceException("该投递缺少关联简历，请选择其他岗位", 400);
            if (resumeId != null && !resumeId.equals(appliedResume))
                throw new ServiceException("面试准备须使用该岗位投递时的简历，请重新选择岗位", 400);
            resumeId = appliedResume;
            data.put("resumeId", resumeId);
            data.put("applicationId", applicationId);
            data.put("job", job(jobs.selectJob(application.getJobId(), userId)));
        }
        if ("interview_preparation".equals(action) && applicationId == null)
            throw new ServiceException("请先选择已投递的岗位", 400);
        if (Set.of("job_recommendation", "resume_analysis", "interview_preparation").contains(action))
        {
            if (resumeId == null) throw new ServiceException("请先选择简历", 400);
            data.put("resume", resume(resumes.selectResume(userId, resumeId)));
        }
        return data;
    }

    public JsonNode definitions()
    {
        var result = json.createArrayNode();
        define(result, "list_resumes", "列出本人简历供用户选择", Map.of(), List.of());
        define(result, "get_resume", "读取本人选定简历的职业能力信息", Map.of("resumeId", Map.of("type", "integer", "minimum", 1)), List.of("resumeId"));
        define(result, "search_jobs", "搜索在招岗位；薪资单位为人民币元/月，不得擅自放宽用户硬条件",
                Map.of("keyword", Map.of("type", "string", "maxLength", 100),
                        "city", Map.of("type", "string", "maxLength", 50),
                        "salaryMin", Map.of("type", "number", "minimum", 0),
                        "page", Map.of("type", "integer", "minimum", 1, "maximum", 5)), List.of());
        define(result, "get_job_detail", "补查公开的在招岗位详情", Map.of("jobId", Map.of("type", "integer", "minimum", 1)), List.of("jobId"));
        define(result, "get_application_history", "查询本人最近投递状态", Map.of(), List.of());
        return result;
    }

    private void define(com.fasterxml.jackson.databind.node.ArrayNode result, String name, String description,
            Map<String, ?> properties, List<String> required)
    {
        result.add(json.valueToTree(Map.of("type", "function", "function", Map.of("name", name,
                "description", description, "parameters", Map.of("type", "object", "properties", properties,
                        "required", required, "additionalProperties", false)))));
    }

    public Object execute(Long userId, Long selectedResumeId, String name, JsonNode args)
    {
        if (userId == null || userId <= 0) throw new ServiceException("请先登录", 401);
        if (args == null || !args.isObject()) throw new ServiceException("工具参数无效", 400);
        return switch (name)
        {
            case "list_resumes" -> {
                allow(args, Set.of());
                yield resumes.selectResumeList(userId).stream().limit(20)
                        .map(r -> fields("resumeId", r.getResumeId(), "name", clean(r.getResumeName(), 100),
                                "direction", clean(r.getJobDirection(), 100))).toList();
            }
            case "get_resume" -> {
                allow(args, Set.of("resumeId"));
                long id = positive(args, "resumeId");
                if (selectedResumeId != null && selectedResumeId != id)
                    throw new ServiceException("请使用本次选择的简历", 403);
                yield resume(resumes.selectResume(userId, id));
            }
            case "search_jobs" -> {
                allow(args, Set.of("keyword", "city", "salaryMin", "page"));
                AgentJobQuery query = new AgentJobQuery();
                query.setKeyword(string(args, "keyword", 100));
                query.setCity(string(args, "city", 50));
                if (args.has("salaryMin"))
                {
                    JsonNode value = args.get("salaryMin");
                    if (!value.isNumber() || value.decimalValue().signum() < 0
                            || value.decimalValue().compareTo(new java.math.BigDecimal("1000000")) > 0)
                        throw new ServiceException("薪资条件无效", 400);
                    query.setSalaryMin(value.decimalValue());
                }
                int page = args.has("page") ? Math.toIntExact(positive(args, "page")) : 1;
                if (page > 5) throw new ServiceException("搜索页数超限", 400);
                query.setPage(page);
                query.setSize(5);
                query.setSort("match");
                var found = jobs.selectJobs(query, userId);
                yield fields("items", found.getItems().stream().map(this::job).toList(),
                        "hasNext", found.isHasNext(), "total", found.getTotal());
            }
            case "get_job_detail" -> {
                allow(args, Set.of("jobId"));
                AgentJob job = jobs.selectJob(positive(args, "jobId"), userId);
                if (!Integer.valueOf(1).equals(job.getStatusCode())) throw new ServiceException("岗位已下架", 404);
                yield job(job);
            }
            case "get_application_history" -> {
                allow(args, Set.of());
                AgentApplicationQuery query = new AgentApplicationQuery();
                query.setSize(10);
                yield applications.selectApplications(query, userId).getItems().stream()
                        .map(a -> fields("applicationId", a.getId(), "jobId", a.getJobId(),
                                "title", clean(a.getJobTitle(), 100), "company", clean(a.getCompanyName(), 100),
                                "status", a.getStatusText())).toList();
            }
            default -> throw new ServiceException("不支持的工具", 400);
        };
    }

    private Map<String, Object> resume(AppResume r)
    {
        return fields("resumeId", r.getResumeId(), "direction", clean(r.getJobDirection(), 100),
                "skills", r.getSkills().stream().limit(30).map(s -> fields("name", clean(s.getName(), 80), "level", s.getLevel())).toList(),
                "educations", r.getEducations().stream().limit(8).map(e -> fields("degree", e.getDegree(), "major", clean(e.getMajor(), 100))).toList(),
                "works", r.getWorks().stream().limit(8).map(w -> fields("position", clean(w.getPosition(), 100),
                        "description", clean(w.getDescription(), 1200), "startDate", String.valueOf(w.getStartDate()),
                        "endDate", String.valueOf(w.getEndDate()))).toList(),
                "projects", r.getProjects().stream().limit(8).map(p -> fields("name", clean(p.getName(), 100),
                        "description", clean(p.getDescription(), 1200), "techStack", clean(p.getTechStack(), 300))).toList());
    }

    public Map<String, Object> job(AgentJob j)
    {
        return fields("positionId", j.getId(), "companyId", j.getCompanyId(), "title", clean(j.getTitle(), 100),
                "company", clean(j.getCompanyName(), 100), "city", clean(j.getWorkCity(), 100),
                "salaryMin", j.getSalaryMin(), "salaryMax", j.getSalaryMax(),
                "experience", clean(j.getExperienceRequired(), 100), "education", j.getEducationRequired(),
                "educationText", j.getEducationText(), "tags", j.getSkills() == null ? List.of()
                        : j.getSkills().stream().limit(30).map(s -> clean(s, 80)).toList(),
                "applied", Integer.valueOf(1).equals(j.getAppliedFlag()),
                "description", description(j), "matchAvailable", false);
    }

    private String description(AgentJob job)
    {
        if (job.getJdJson() != null)
        {
            try
            {
                JsonNode node = json.readTree(job.getJdJson()).path("description");
                if (node.isTextual()) return clean(node.asText(), 2500);
            }
            catch (com.fasterxml.jackson.core.JsonProcessingException ignored) { }
        }
        List<String> lines = new ArrayList<>();
        if (job.getResponsibilities() != null) lines.addAll(job.getResponsibilities());
        if (job.getRequirements() != null) lines.addAll(job.getRequirements());
        return clean(String.join("\n", lines), 2500);
    }

    public List<Map<String, Object>> refreshCards(Long userId, Set<Long> ids)
    {
        List<Map<String, Object>> cards = new ArrayList<>();
        for (Long id : ids.stream().limit(5).toList())
        {
            try
            {
                AgentJob job = jobs.selectJob(id, userId);
                if (Integer.valueOf(1).equals(job.getStatusCode())) cards.add(job(job));
            }
            catch (ServiceException ignored) { /* Unavailable jobs are omitted. */ }
        }
        return cards;
    }

    static void allow(JsonNode args, Set<String> names)
    {
        args.fieldNames().forEachRemaining(key -> {
            if (!names.contains(key)) throw new ServiceException("工具参数无效", 400);
        });
    }

    static long positive(JsonNode args, String key)
    {
        JsonNode value = args.get(key);
        if (value == null || !value.isIntegralNumber() || !value.canConvertToLong() || value.longValue() <= 0)
            throw new ServiceException("工具编号无效", 400);
        return value.longValue();
    }

    static String string(JsonNode args, String key, int max)
    {
        JsonNode value = args.get(key);
        if (value == null) return null;
        if (!value.isTextual() || value.asText().length() > max) throw new ServiceException("工具参数无效", 400);
        return value.asText();
    }

    public static String clean(String value, int max)
    {
        if (value == null) return null;
        String safe = value.substring(0, Math.min(max, value.length()));
        return safe.replaceAll("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "[邮箱已隐藏]")
                .replaceAll("(?<!\\d)1[3-9]\\d{9}(?!\\d)", "[手机号已隐藏]")
                .replaceAll("(?<!\\d)\\d{17}[0-9Xx](?!\\d)", "[身份信息已隐藏]");
    }

    public static Map<String, Object> fields(Object... values)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        for (int i = 0; i < values.length; i += 2) result.put((String) values[i], values[i + 1]);
        return result;
    }
}
