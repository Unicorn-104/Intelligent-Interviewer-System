package com.ruoyi.system.service.app.impl;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ModelProvider;
import com.ruoyi.system.domain.app.AppJob;
import com.ruoyi.system.domain.app.AppJobRecommendation;
import com.ruoyi.system.domain.app.AppRecommendRequest;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.service.IModelProviderService;
import com.ruoyi.system.service.app.IAppJobService;
import com.ruoyi.system.service.app.IAppRecommendService;
import com.ruoyi.system.service.app.IAppResumeService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/** C-App AI 简历推荐服务：规则粗筛候选池，DeepSeek 精排并给出理由。 */
@Service
public class AppRecommendServiceImpl implements IAppRecommendService
{
    private static final Logger log = LoggerFactory.getLogger(AppRecommendServiceImpl.class);

    private static final String DEFAULT_API_URL = "https://api.deepseek.com/chat/completions";
    private static final String DEFAULT_MODEL = "deepseek-chat";
    private static final int DEFAULT_POOL_SIZE = 20;
    private static final int DEFAULT_LIMIT = 10;
    private static final Duration LLM_TIMEOUT = Duration.ofSeconds(30);

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    private IAppResumeService resumeService;

    @Autowired
    private IAppJobService jobService;

    @Autowired
    private IModelProviderService modelProviderService;

    @Override
    public List<AppJobRecommendation> recommend(Long userId, AppRecommendRequest request)
    {
        // 校验简历归属并取全量结构化数据（越权/不存在会在此抛出）
        AppResume resume = resumeService.selectResume(userId, request.getResumeId());

        int poolSize = normalize(request.getPoolSize(), DEFAULT_POOL_SIZE, 50);
        int limit = normalize(request.getLimit(), DEFAULT_LIMIT, 20);

        List<AppJob> pool = jobService.selectJobs(userId, request.getKeyword(), request.getFilter(), poolSize);
        if (pool.isEmpty())
        {
            return new ArrayList<>();
        }

        ModelProvider provider = resolveProvider();
        try
        {
            String content = callDeepSeek(provider, buildPrompt(resume, pool));
            Map<Long, Integer> scores = new LinkedHashMap<>();
            Map<Long, String> reasons = new LinkedHashMap<>();
            parseRecommendations(content, scores, reasons);

            Map<Long, AppJob> byId = pool.stream()
                    .collect(Collectors.toMap(AppJob::getPositionId, Function.identity(), (a, b) -> a));
            List<AppJobRecommendation> result = new ArrayList<>();
            scores.forEach((positionId, score) -> {
                AppJob job = byId.get(positionId);
                if (job == null) return;
                AppJobRecommendation item = toRecommendation(job);
                item.setMatchScore(clamp(score));
                item.setReason(reasons.get(positionId));
                result.add(item);
            });
            if (result.isEmpty())
            {
                return fallback(pool, limit);
            }
            result.sort(Comparator.comparing(AppJobRecommendation::getMatchScore,
                    Comparator.nullsLast(Comparator.reverseOrder())));
            return result.size() > limit ? new ArrayList<>(result.subList(0, limit)) : result;
        }
        catch (Exception error)
        {
            log.warn("AI 简历推荐调用失败，降级为规则匹配：{}", error.getMessage());
            return fallback(pool, limit);
        }
    }

    private ModelProvider resolveProvider()
    {
        List<ModelProvider> providers = modelProviderService.selectModelProviderList(new ModelProvider());
        ModelProvider active = providers.stream()
                .filter(provider -> Integer.valueOf(1).equals(provider.getMppStatus()))
                .filter(provider -> provider.getMppApiKey() != null && !provider.getMppApiKey().isBlank())
                .findFirst()
                .orElse(null);
        if (active == null)
        {
            throw new ServiceException("AI 推荐服务未配置，请联系管理员");
        }
        return active;
    }

    private String buildPrompt(AppResume resume, List<AppJob> pool) throws Exception
    {
        String resumeJson = objectMapper.writeValueAsString(buildResumeNode(resume));
        String jobsJson = objectMapper.writeValueAsString(buildJobsNode(pool));
        return "请根据候选人的简历与候选岗位列表，评估每个岗位与该简历的匹配度，"
                + "按匹配度从高到低返回推荐。只输出 JSON，不要输出任何其他文字，格式为："
                + "{\"recommendations\":[{\"positionId\":<岗位ID>,\"matchScore\":<0到100的整数>,\"reason\":\"<一句话理由>\"}]}，"
                + "positionId 只能从给定岗位的 positionId 中选择，不要编造或新增。\n\n"
                + "简历：\n" + resumeJson + "\n\n"
                + "岗位列表：\n" + jobsJson;
    }

    private ObjectNode buildResumeNode(AppResume resume)
    {
        ObjectNode root = objectMapper.createObjectNode();
        root.put("resumeName", resume.getResumeName());
        root.put("jobDirection", resume.getJobDirection());

        ArrayNode skills = root.putArray("skills");
        for (AppResume.Skill item : resume.getSkills())
        {
            ObjectNode node = skills.addObject();
            node.put("name", item.getName());
            node.put("level", item.getLevel() == null ? 2 : item.getLevel());
        }

        ArrayNode educations = root.putArray("educations");
        for (AppResume.Education item : resume.getEducations())
        {
            ObjectNode node = educations.addObject();
            node.put("school", item.getSchool());
            node.put("major", item.getMajor());
            node.put("degree", item.getDegree());
        }

        ArrayNode works = root.putArray("works");
        for (AppResume.Work item : resume.getWorks())
        {
            ObjectNode node = works.addObject();
            node.put("company", item.getCompany());
            node.put("position", item.getPosition());
            node.put("description", item.getDescription());
        }

        ArrayNode projects = root.putArray("projects");
        for (AppResume.Project item : resume.getProjects())
        {
            ObjectNode node = projects.addObject();
            node.put("name", item.getName());
            node.put("description", item.getDescription());
            node.put("techStack", item.getTechStack());
        }
        return root;
    }

    private ObjectNode buildJobsNode(List<AppJob> pool)
    {
        ObjectNode root = objectMapper.createObjectNode();
        ArrayNode jobs = root.putArray("jobs");
        for (AppJob job : pool)
        {
            ObjectNode node = jobs.addObject();
            node.put("positionId", job.getPositionId());
            node.put("title", job.getTitle());
            node.put("company", job.getCompany());
            node.put("city", job.getCity());
            node.put("salaryMin", job.getSalaryMin());
            node.put("salaryMax", job.getSalaryMax());
            node.put("experience", job.getExperience());
            node.put("education", job.getEducation());
            ArrayNode tags = node.putArray("tags");
            for (String tag : job.getTags()) tags.add(tag);
            node.put("description", job.getDescription());
        }
        return root;
    }

    private String callDeepSeek(ModelProvider provider, String prompt) throws Exception
    {
        String url = blankToDefault(provider.getMppApiUrl(), DEFAULT_API_URL);
        String model = blankToDefault(provider.getMppModelName(), DEFAULT_MODEL);

        ObjectNode body = objectMapper.createObjectNode();
        body.put("model", model);
        ArrayNode messages = body.putArray("messages");
        messages.addObject().put("role", "system").put("content", "你是资深 HR 与人岗匹配专家，只输出 JSON，不输出多余文字。");
        messages.addObject().put("role", "user").put("content", prompt);
        body.putObject("response_format").put("type", "json_object");
        body.put("temperature", 0.3);
        body.put("max_tokens", 2000);
        body.put("stream", false);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(LLM_TIMEOUT)
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + provider.getMppApiKey())
                .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(body)))
                .build();

        HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300)
        {
            throw new IllegalStateException("DeepSeek 返回 HTTP " + response.statusCode());
        }
        JsonNode root = objectMapper.readTree(response.body());
        return root.path("choices").path(0).path("message").path("content").asText();
    }

    private void parseRecommendations(String content, Map<Long, Integer> scores, Map<Long, String> reasons)
            throws Exception
    {
        JsonNode root = objectMapper.readTree(content);
        JsonNode list = root.path("recommendations");
        if (!list.isArray())
        {
            return;
        }
        for (JsonNode node : list)
        {
            Long positionId = longOf(node.get("positionId"));
            if (positionId == null || positionId <= 0)
            {
                continue;
            }
            scores.putIfAbsent(positionId, clamp(intOf(node.get("matchScore"))));
            reasons.putIfAbsent(positionId, textOf(node.get("reason")));
        }
    }

    private List<AppJobRecommendation> fallback(List<AppJob> pool, int limit)
    {
        return pool.stream()
                .sorted(Comparator.comparing(AppJob::getMatchScore,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .limit(limit)
                .map(this::toRecommendation)
                .collect(Collectors.toList());
    }

    private AppJobRecommendation toRecommendation(AppJob job)
    {
        AppJobRecommendation item = new AppJobRecommendation();
        item.setPositionId(job.getPositionId());
        item.setTitle(job.getTitle());
        item.setCompanyId(job.getCompanyId());
        item.setCompany(job.getCompany());
        item.setCompanyLogo(job.getCompanyLogo());
        item.setCompanyVerified(job.getCompanyVerified());
        item.setCity(job.getCity());
        item.setSalaryMin(job.getSalaryMin());
        item.setSalaryMax(job.getSalaryMax());
        item.setExperience(job.getExperience());
        item.setEducation(job.getEducation());
        item.setJobType(job.getJobType());
        item.setMatchScore(job.getMatchScore());
        item.setDescription(job.getDescription());
        item.setTagsCsv(job.getTags().isEmpty() ? null : String.join(",", job.getTags()));
        item.setApplied(job.getApplied());
        return item;
    }

    private Long longOf(JsonNode node)
    {
        if (node == null || node.isNull()) return null;
        if (node.isNumber()) return node.asLong();
        try
        {
            return Long.parseLong(node.asText().trim());
        }
        catch (NumberFormatException error)
        {
            return null;
        }
    }

    private int intOf(JsonNode node)
    {
        if (node == null || node.isNull()) return 0;
        if (node.isNumber()) return node.asInt();
        try
        {
            return Integer.parseInt(node.asText().trim());
        }
        catch (NumberFormatException error)
        {
            return 0;
        }
    }

    private String textOf(JsonNode node)
    {
        if (node == null || node.isNull() || node.asText().isBlank()) return null;
        return node.asText().trim();
    }

    private int clamp(int value)
    {
        return Math.max(0, Math.min(100, value));
    }

    private int normalize(Integer value, int defaultValue, int max)
    {
        if (value == null) return defaultValue;
        return Math.max(1, Math.min(value, max));
    }

    private String blankToDefault(String value, String defaultValue)
    {
        return value == null || value.isBlank() ? defaultValue : value.trim();
    }
}
