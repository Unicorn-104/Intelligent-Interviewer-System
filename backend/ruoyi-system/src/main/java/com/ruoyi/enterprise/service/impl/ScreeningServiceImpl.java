package com.ruoyi.enterprise.service.impl;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.IScreeningService;
import com.ruoyi.enterprise.service.TalStatusService;
import com.ruoyi.enterprise.service.screening.ScreeningAiEvaluator;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.service.app.pdf.ResumePdfParser;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;

/** Real, evidence-based AI evaluation. Running tasks never hold a database transaction across HTTP calls. */
@Service
public class ScreeningServiceImpl implements IScreeningService
{
    /** 初筛通过线：AI 六维加权总分达到该值即可进入初筛通过 */
    public static final double PASS_THRESHOLD = 60.0;

    @Autowired private ScreeningMapper screeningMapper;
    @Autowired private TalStatusService talStatusService;
    @Autowired private DashboardMapper dashboardMapper;
    @Autowired private ScreeningAiEvaluator evaluator;
    @Autowired private ResumePdfStorage pdfStorage;
    @Autowired private ResumePdfParser pdfParser;
    @Autowired private PlatformTransactionManager transactionManager;
    private final ExecutorService workers = Executors.newFixedThreadPool(2);
    private final Semaphore capacity = new Semaphore(2);

    @PreDestroy
    public void shutdown() { workers.shutdownNow(); }

    @Override
    public Map<String, Object> triggerScreening(Long userId, Long positionId, Integer topN)
    {
        Map<String, Object> task = triggerScreeningAsync(userId, positionId, topN);
        long deadline = System.nanoTime() + TimeUnit.MINUTES.toNanos(12);
        while (Boolean.TRUE.equals(task.get("processing")))
        {
            if (System.nanoTime() > deadline) throw new ServiceException("AI筛选仍在后台进行，请稍后读取结果，无需重复提交");
            try { Thread.sleep(200); }
            catch (InterruptedException error)
            {
                Thread.currentThread().interrupt();
                throw new ServiceException("请求已中断，筛选任务仍在后台进行，请稍后读取结果");
            }
            task = getTaskStatus(userId, positionId);
        }
        if ("failed".equals(task.get("state"))) throw new ServiceException(String.valueOf(task.get("error")));
        task = new LinkedHashMap<>(task);
        task.put("topN", topN == null ? 20 : topN);
        return task;
    }

    @Override
    public Map<String, Object> triggerScreeningAsync(Long userId, Long positionId, Integer topN)
    {
        return triggerScreeningAsync(userId, positionId, topN, false);
    }

    @Override
    public Map<String, Object> triggerScreeningAsync(Long userId, Long positionId, Integer topN, boolean fullAnalysis)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> job = requirePosition(companyId, positionId);
        if (topN != null && (topN < 1 || topN > 200)) throw new ServiceException("短名单人数须为1至200");
        // 只筛选仍停留在待筛选(0)的投递，避免重筛改写已约面/笔试/录用/撤回的投递状态
        List<Map<String, Object>> candidates = screeningMapper.selectScreenableCandidates(positionId);
        if (candidates.isEmpty())
            return Map.of("taskId", positionId, "state", "completed", "processing", false,
                    "candidateCount", 0, "completedCount", 0, "skippedCount", 0,
                    "results", listResults(userId, positionId),
                    "message", "该岗位暂无待初筛的投递");
        Map<String, Object> current = screeningMapper.selectTaskStatus(companyId, positionId);
        // A processing task is shared; claimTask below recovers a stale lease.
        if (current != null && "processing".equals(current.get("state")))
        {
            Object updated = current.get("updatedAt");
            if (updated != null && java.time.LocalDateTime.parse(updated.toString(),
                    java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
                    .isAfter(java.time.LocalDateTime.now().minusMinutes(15))) return taskView(current);
        }
        int total = candidates.size();
        if (!fullAnalysis)
        {
            Map<Long, Map<String, Object>> analyzed = new java.util.HashMap<>();
            for (Map<String, Object> row : screeningMapper.selectAnalyzedCandidates(companyId, positionId))
                analyzed.put(Long.valueOf(row.get("candidateId").toString()), row);
            candidates = candidates.stream().filter(candidate ->
                    !analyzed.containsKey(Long.valueOf(candidate.get("talentId").toString()))).toList();
        }
        if (candidates.isEmpty())
            return Map.of("taskId", positionId, "state", "completed", "processing", false,
                    "candidateCount", 0, "completedCount", 0, "skippedCount", total,
                    "results", listResults(userId, positionId),
                    "message", "已优先读取数据库中的分析结果；没有待补充的新分析");
        final List<Map<String, Object>> pending = candidates;
        if (!capacity.tryAcquire())
        {
            if (current != null && "processing".equals(current.get("state"))) return taskView(current);
            throw new ServiceException("AI筛选任务繁忙，请稍后重试");
        }
        String runId = UUID.randomUUID().toString();
        boolean dispatched = false;
        try
        {
            job.put("requiredSkills", screeningMapper.selectPositionSkills(positionId));
            screeningMapper.initTask(companyId, positionId);
            if (screeningMapper.claimTask(companyId, positionId, runId, candidates.size()) == 0)
                return taskView(screeningMapper.selectTaskStatus(companyId, positionId));
            Map<String, Object> reply = taskView(screeningMapper.selectTaskStatus(companyId, positionId));
            reply.put("skippedCount", total - pending.size());
            reply.put("fullAnalysis", fullAnalysis);
            workers.execute(() -> runScreening(companyId, positionId, runId, job, pending, fullAnalysis));
            dispatched = true;
            return reply;
        }
        catch (RuntimeException error)
        {
            try { screeningMapper.updateTask(companyId, positionId, runId, "failed", 0, 0, "AI筛选任务启动失败，请稍后重试"); }
            catch (RuntimeException ignored) { }
            throw error;
        }
        finally { if (!dispatched) capacity.release(); }
    }

    private void runScreening(Long companyId, Long positionId, String runId, Map<String, Object> job,
            List<Map<String, Object>> candidates, boolean fullAnalysis)
    {
        int completed = 0;
        int scored = 0;
        try
        {
            // Each request contains exactly one resume; previous scores/ranks are never model input.
            for (Map<String, Object> candidate : candidates)
            {
                if (Thread.currentThread().isInterrupted()) throw new ServiceException("AI筛选任务已中断");
                Map<String, Object> analysis = evaluator.evaluate(job, List.of(resumeEvidence(candidate))).get(0);
                int nextCompleted = completed + 1;
                int nextScored = scored + (analysis.get("totalScore") == null ? 0 : 1);
                new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
                    Map<String, Object> task = screeningMapper.lockTask(companyId, positionId);
                    if (task == null || !runId.equals(task.get("runId"))) throw new ServiceException("AI筛选任务已被更新");
                    Map<String, Object> currentJob = requirePosition(companyId, positionId);
                    if (!java.util.Objects.equals(job.get("positionVersion"), currentJob.get("positionVersion")))
                        throw new ServiceException("分析期间岗位发生变化，请重试；已完成结果已保留");
                    long id = Long.parseLong(candidate.get("talentId").toString());
                    Map<String, Object> latest = screeningMapper.selectCandidatesByPosition(positionId).stream()
                            .filter(c -> Long.parseLong(c.get("talentId").toString()) == id).findFirst().orElse(null);
                    if (latest == null || !java.util.Objects.equals(candidate.get("resumeId"), latest.get("resumeId"))
                            || !java.util.Objects.equals(candidate.get("resumeVersion"), latest.get("resumeVersion")))
                        throw new ServiceException("分析期间求职者或简历发生变化，请重试；已完成结果已保留");
                    // The run lease and task lock prevent concurrent writers to this company/job pair.
                    analysis.put("positionId", positionId);
                    analysis.put("positionTitle", job.get("title"));
                    analysis.put("resumeId", candidate.get("resumeId"));
                    analysis.put("positionVersion", job.get("positionVersion"));
                    analysis.put("resumeVersion", candidate.get("resumeVersion"));
                    analysis.put("analysisMode", fullAnalysis ? "full" : "incremental");
                    Map<String, Object> row = new LinkedHashMap<>(analysis);
                    row.put("companyId", companyId);
                    row.put("report", JSON.toJSONString(analysis));
                    screeningMapper.saveAnalysis(row);
                    // AI 初筛完成后同步回写该岗位该候选人的投递记录（评分 + 初筛状态）
                    Double totalScore = asDouble(analysis.get("totalScore"));
                    if (totalScore != null)
                    {
                        // 仅回写仍处于待筛选(0)的投递；若 HR 已复核或已进入后续环节则不覆盖
                        screeningMapper.updateApplicationByCandidate(positionId, id, totalScore,
                                totalScore >= PASS_THRESHOLD ? 1 : 2, List.of(0));
                    }
                    // Result and progress commit together. No HTTP/model call inside this transaction.
                    String state = nextCompleted == candidates.size() ? "completed" : "processing";
                    if (screeningMapper.updateTask(companyId, positionId, runId, state,
                            nextCompleted, nextScored, null) == 0) throw new ServiceException("AI筛选任务已被更新");
                });
                completed = nextCompleted;
                scored = nextScored;
            }
        }
        catch (RuntimeException error)
        {
            String message = error instanceof ServiceException ? error.getMessage() : "AI筛选失败，请稍后重试";
            message += "；已完成的独立分析已保存，重试增量分析仅处理尚无结果的求职者";
            try { screeningMapper.updateTask(companyId, positionId, runId, "failed", completed, scored, message); }
            catch (RuntimeException ignored) { /* Never log resumes, credentials or database details. */ }
        }
        finally
        {
            // 任务结束（含失败）统一同步一次：已有分析结果的投递按评分回写，
            // 无分析结果（评估失败）的投递保持待筛选，等待 HR 人工评分
            try { syncScreenedApplications(companyId, positionId); }
            catch (RuntimeException ignored) { /* 同步失败不影响已保存的分析结果 */ }
            capacity.release();
        }
    }

    private Map<String, Object> resumeEvidence(Map<String, Object> candidate)
    {
        Long id = Long.valueOf(candidate.get("talentId").toString());
        Long resumeId = candidate.get("resumeId") == null ? null : Long.valueOf(candidate.get("resumeId").toString());
        Map<String, Object> evidence = new LinkedHashMap<>();
        evidence.put("candidateId", id);
        evidence.put("skills", resumeId == null ? List.of() : screeningMapper.selectCandidateSkills(id));
        evidence.put("education", resumeId == null ? List.of() : screeningMapper.selectEducationEvidence(resumeId));
        evidence.put("workAndInternships", resumeId == null ? List.of() : screeningMapper.selectWorkEvidence(resumeId));
        evidence.put("projects", resumeId == null ? List.of() : screeningMapper.selectProjectEvidence(resumeId));
        List<String> warnings = new ArrayList<>();
        Object reference = candidate.get("fileReference");
        if (reference != null && !reference.toString().isBlank() && candidate.get("resumeUserId") != null)
        {
            try
            {
                Path file = pdfStorage.read(Long.valueOf(candidate.get("resumeUserId").toString()), reference.toString());
                if (Files.size(file) > 10 * 1024 * 1024) throw new ServiceException("原始简历过大");
                String text = redact(pdfParser.parse(Files.readAllBytes(file)).text());
                if (text.length() > 16000)
                {
                    text = text.substring(0, 16000);
                    warnings.add("原始简历较长，仅分析前16000字，未覆盖内容待人工核实");
                }
                evidence.put("originalResumeText", text);
            }
            catch (java.io.IOException | ServiceException error)
            {
                warnings.add("原始简历暂无法读取，本次仅依据结构化简历分析");
            }
        }
        else warnings.add("未提供原始简历，科研和荣誉仅从已保存经历中提取，未提供内容不评分");
        evidence.put("sourceWarnings", warnings);
        // Also sanitize free-form structured descriptions before sending them to the model.
        return sanitizeMap(evidence);
    }

    private static Map<String, Object> sanitizeMap(Map<String, Object> input)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        input.forEach((key, value) -> result.put(key, sanitize(value)));
        return result;
    }

    private static Object sanitize(Object value)
    {
        if (value instanceof String text) return redact(text);
        if (value instanceof List<?> list) return list.stream().map(ScreeningServiceImpl::sanitize).toList();
        if (value instanceof Map<?, ?> map)
        {
            Map<String, Object> result = new LinkedHashMap<>();
            map.forEach((key, item) -> result.put(key.toString(), sanitize(item)));
            return result;
        }
        return value;
    }

    private static String redact(String text)
    {
        return text.replaceAll("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "[联系方式已隐藏]")
                .replaceAll("(?<![0-9])(?:\\+?86[- ]?)?1[3-9][0-9]{9}(?![0-9])", "[联系方式已隐藏]")
                .replaceAll("(?<![0-9])[1-9][0-9]{16}[0-9Xx](?![0-9])", "[身份信息已隐藏]")
                .replaceAll("(?m)^(?:姓名|性别|年龄|民族|婚育|籍贯|住址|身份证|联系电话|邮箱)[:：].*$", "[个人信息已隐藏]");
    }

    @Override
    public Map<String, Object> getTaskStatus(Long userId, Long taskId)
    {
        Long companyId = resolveCompanyId(userId);
        requirePosition(companyId, taskId);
        return taskView(screeningMapper.selectTaskStatus(companyId, taskId));
    }

    private Map<String, Object> taskView(Map<String, Object> task)
    {
        if (task == null) return Map.of("state", "idle", "processing", false);
        Map<String, Object> result = new LinkedHashMap<>(task);
        result.remove("runId");
        result.put("processing", "processing".equals(task.get("state")));
        return result;
    }

    @Override
    public Map<String, Object> screenPendingApplications(Long userId, Long positionId)
    {
        Long companyId = resolveCompanyId(userId);
        requirePosition(companyId, positionId);
        List<Map<String, Object>> applications = screeningMapper.selectPendingApplications(positionId);
        if (applications.isEmpty())
        {
            Map<String, Object> empty = new LinkedHashMap<>();
            empty.put("positionId", positionId);
            empty.put("state", "completed");
            empty.put("processing", false);
            empty.put("message", "该岗位暂无待初筛的投递");
            return empty;
        }
        // 已有 AI 分析结果的投递直接按真实评分回写，避免前台长期停留在待筛选
        int writtenBack = syncScreenedApplications(companyId, positionId);
        Map<String, Object> task = new LinkedHashMap<>(triggerScreeningAsync(userId, positionId, 20));
        task.put("writtenBackCount", writtenBack);
        return task;
    }

    /** 按已有 AI 分析结果回写待筛选投递的评分与初筛状态；无分析结果（评估失败）的保持待筛选，可人工评分。 */
    private int syncScreenedApplications(Long companyId, Long positionId)
    {
        int writtenBack = 0;
        for (Map<String, Object> application : screeningMapper.selectPendingApplications(positionId))
        {
            Long talId = Long.valueOf(String.valueOf(application.get("talentId")));
            Map<String, Object> analysis = readAnalysis(screeningMapper.selectAnalysis(companyId, positionId, talId));
            Double score = analysis == null ? null : asDouble(analysis.get("totalScore"));
            if (score == null)
            {
                continue;
            }
            screeningMapper.updateApplicationScreened(Long.valueOf(String.valueOf(application.get("applicationId"))),
                    score, score >= PASS_THRESHOLD ? 1 : 2);
            writtenBack++;
        }
        return writtenBack;
    }

    @Override
    public Map<String, Object> syncAllPendingApplications(Long userId)
    {
        Long companyId = resolveCompanyId(userId);
        int synced = 0;
        int touchedPositions = 0;
        for (Long positionId : screeningMapper.selectPendingPositions(companyId))
        {
            int count = syncScreenedApplications(companyId, positionId);
            if (count > 0)
            {
                touchedPositions++;
            }
            synced += count;
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("syncedApplications", synced);
        result.put("positions", touchedPositions);
        result.put("message", synced == 0
                ? "暂无可用 AI 分析结果回写的待筛选投递"
                : "已按 AI 分析结果回写 " + synced + " 条投递的评分和初筛状态");
        return result;
    }

    @Override
    public Map<String, Object> screenAllPendingPositions(Long userId)
    {
        Long companyId = resolveCompanyId(userId);
        List<Long> positionIds = screeningMapper.selectPendingPositions(companyId);
        int queuedPositions = 0;
        int queuedCandidates = 0;
        int skippedPositions = 0;
        for (Long positionId : positionIds)
        {
            try
            {
                Map<String, Object> task = triggerScreeningAsync(userId, positionId, 20);
                // 仅本次真正派发的新任务计入排队；已在处理中的岗位与无新人选的岗位跳过
                if (!task.containsKey("fullAnalysis"))
                {
                    skippedPositions++;
                    continue;
                }
                queuedPositions++;
                int candidateCount = asInt(task.get("candidateCount"));
                int skippedCount = asInt(task.get("skippedCount"));
                queuedCandidates += Math.max(0, candidateCount - skippedCount);
            }
            catch (RuntimeException error)
            {
                skippedPositions++;
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("queuedPositions", queuedPositions);
        result.put("queuedCandidates", queuedCandidates);
        result.put("skippedPositions", skippedPositions);
        result.put("message", queuedPositions == 0
                ? "暂无需要发起 AI 初筛的岗位"
                : "已为 " + queuedPositions + " 个岗位发起 AI 初筛，共 " + queuedCandidates + " 位求职者");
        return result;
    }

    @Override
    public List<Map<String, Object>> listTasks(Long userId, Integer pageNum, Integer pageSize)
    {
        Long companyId = resolveCompanyId(userId);
        PageUtils.startPage(pageNum, pageSize);
        try
        {
            return screeningMapper.selectTaskList(companyId);
        }
        finally
        {
            PageUtils.clearPage();
        }
    }

    @Override
    public List<Map<String, Object>> listResults(Long userId, Long taskId)
    {
        Long companyId = resolveCompanyId(userId);
        requirePosition(companyId, taskId);
        List<Map<String, Object>> candidates = screeningMapper.selectResultsByPosition(taskId);
        // 岗位必备技能整批只查一次，供逐行硬性条件比对
        List<String> requiredSkills = screeningMapper.selectPositionSkills(taskId);
        for (Map<String, Object> candidate : candidates)
        {
            Long id = Long.valueOf(candidate.get("resultId").toString());
            Map<String, Object> analysis = readAnalysis(screeningMapper.selectAnalysis(companyId, taskId, id));
            // Old rule-based scores must never be presented as a completed AI evaluation.
            candidate.put("totalScore", null);
            for (String key : ScreeningAiEvaluator.WEIGHTS.keySet()) candidate.put(key, null);
            candidate.put("source", "not_analyzed");
            if (analysis != null) candidate.putAll(analysis);
            Double totalScore = asDouble(candidate.get("totalScore"));
            List<String> missingSkills = missingSkills(requiredSkills, screeningMapper.selectCandidateSkills(id));
            candidate.put("threshold", PASS_THRESHOLD);
            candidate.put("passed", totalScore != null && totalScore >= PASS_THRESHOLD);
            candidate.put("requiredSkills", requiredSkills);
            candidate.put("missingSkills", missingSkills);
            candidate.put("hardFilterPassed", requiredSkills.isEmpty() || missingSkills.size() < requiredSkills.size());
        }
        candidates.sort(Comparator.comparing((Map<String, Object> c) ->
                c.get("totalScore") instanceof Number n ? n.doubleValue() : -1.0).reversed());
        return candidates;
    }

    /** 必备技能中未被候选人技能覆盖的部分（忽略大小写与首尾空白） */
    private List<String> missingSkills(List<String> requiredSkills, List<String> candidateSkills)
    {
        List<String> missing = new ArrayList<>();
        if (requiredSkills.isEmpty()) return missing;
        List<String> owned = new ArrayList<>();
        if (candidateSkills != null)
        {
            for (String skill : candidateSkills)
            {
                if (skill != null) owned.add(skill.trim().toLowerCase());
            }
        }
        for (String required : requiredSkills)
        {
            if (required != null && !owned.contains(required.trim().toLowerCase())) missing.add(required);
        }
        return missing;
    }

    @Override
    public List<Map<String, Object>> listShortlist(Long userId, Long taskId, Integer topN)
    {
        if (topN != null && (topN < 1 || topN > 200)) throw new ServiceException("短名单人数须为1至200");
        List<Map<String, Object>> results = listResults(userId, taskId);
        results.removeIf(row -> row.get("totalScore") == null);
        return results.subList(0, topN == null ? results.size() : Math.min(topN, results.size()));
    }

    @Override
    public Map<String, Object> getReport(Long userId, Long resultId)
    {
        Long companyId = resolveCompanyId(userId);
        requireCandidate(companyId, resultId);
        Map<String, Object> report = readAnalysis(screeningMapper.selectLatestAnalysis(companyId, resultId));
        if (report == null) throw new ServiceException("该候选人暂无 AI 推荐报告（请先在岗位中运行AI辅助筛选）");
        return report;
    }

    private Map<String, Object> readAnalysis(Map<String, Object> row)
    {
        if (row == null || row.get("report") == null) return null;
        Map<String, Object> report = JSON.parseObject(row.get("report").toString());
        // 只认 AI 真实评估（llm）与 HR 人工评分（manual），历史规则分不作为有效结果
        if (!"llm".equals(report.get("source")) && !"manual".equals(report.get("source"))) return null;
        // Normalize cached pre-zero-policy reports without invoking the provider or writing on GET.
        // Retain original evidence and distinguish missing material from a model-backed zero.
        if (report.get("dimensions") instanceof Map<?, ?> storedDimensions)
        {
            double weighted = 0;
            Map<String, Object> normalized = new LinkedHashMap<>();
            for (Map.Entry<String, Integer> entry : ScreeningAiEvaluator.WEIGHTS.entrySet())
            {
                Object raw = storedDimensions.get(entry.getKey());
                Map<String, Object> dimension = new LinkedHashMap<>();
                if (raw instanceof Map<?, ?> values)
                    values.forEach((key, value) -> dimension.put(key.toString(), value));
                Object rawScore = dimension.get("score");
                double score = rawScore instanceof Number n && Double.isFinite(n.doubleValue())
                        ? n.doubleValue() : 0.0;
                dimension.put("score", score);
                dimension.put("weight", entry.getValue());
                if (rawScore == null) dimension.put("evidence", List.of());
                normalized.put(entry.getKey(), dimension);
                report.put(entry.getKey(), score);
                weighted += score * entry.getValue();
            }
            report.put("dimensions", normalized);
            report.put("totalScore", Math.round(weighted / 100.0 * 10.0) / 10.0);
            report.put("scoringPolicy", "missing-zero-v1");
        }
        // HR 复核调整过的分数优先展示，其余评分逻辑保持不变
        Double adjusted = asDouble(report.get("adjustedTotalScore"));
        if (adjusted != null) report.put("totalScore", adjusted);
        report.putIfAbsent("adjustedTotalScore", adjusted);
        report.putIfAbsent("hrAdjusted", adjusted != null);
        report.put("generatedAt", row.get("generatedAt"));
        report.put("content", report.get("recommendation"));
        List<String> points = new ArrayList<>();
        Object dimensions = report.get("dimensions");
        if (dimensions instanceof Map<?, ?> map)
        {
            for (Object dimension : map.values())
                if (dimension instanceof Map<?, ?> data && data.get("score") != null && data.get("evidence") instanceof List<?> quotes)
                    for (Object quote : quotes) points.add(quote.toString());
        }
        report.put("matchPoints", points.stream().distinct().toList());
        return report;
    }

    @Override
    public Map<String, Object> getGreeting(Long userId, Long resultId)
    {
        requireCandidate(resolveCompanyId(userId), resultId);
        Map<String, Object> record = screeningMapper.selectGreetingByCandidate(resultId);
        if (record == null) throw new ServiceException("该候选人暂无个性化招呼语（Top 3 才自动生成）");
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", record.get("content"));
        result.put("status", record.get("status"));
        result.put("sentAt", record.get("sentAt"));
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> reviewResult(Long userId, Long resultId, Boolean approved, Double adjustScore,
            Long positionId)
    {
        Long companyId = resolveCompanyId(userId);
        requireCandidate(companyId, resultId);
        // approved 为空且未填分数时无从判断；只填分数表示 HR 对未完成 AI 评估的候选人进行人工评分
        if (approved == null && adjustScore == null) throw new ServiceException("请选择复核结论或填写人工评分");
        if (adjustScore != null && (!Double.isFinite(adjustScore) || adjustScore < 0 || adjustScore > 100))
            throw new ServiceException("调整评分须为0至100");
        if (positionId != null)
        {
            requirePosition(companyId, positionId);
            // 复核必须落在该候选人真实投递过的岗位上，避免跨岗位改写投递记录
            if (screeningMapper.countOwnedApplication(companyId, positionId, resultId) == 0)
                throw new ServiceException("该候选人未投递当前岗位，无法复核");
        }
        if (approved == null && positionId == null) throw new ServiceException("人工评分须指定岗位");
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("resultId", resultId);
        result.put("approved", approved);
        Double currentScore = null;
        if (adjustScore != null)
        {
            double rounded = Math.round(adjustScore * 10.0) / 10.0;
            screeningMapper.updateMatchedScore(resultId, rounded);
            result.put("adjustScore", rounded);
            currentScore = rounded;
            // HR 调整后的分数写回 AI 分析报告，列表与报告统一按调整后总分展示
            if (positionId != null)
            {
                writeAdjustedReport(companyId, positionId, resultId, rounded);
                // 同步投递记录的匹配度，人才库/投递列表与报告展示同一分数
                screeningMapper.updateApplicationScore(positionId, resultId, rounded, List.of(0, 1));
            }
        }
        else if (positionId != null)
        {
            Map<String, Object> analysis = readAnalysis(screeningMapper.selectAnalysis(companyId, positionId, resultId));
            currentScore = analysis == null ? null : asDouble(analysis.get("totalScore"));
        }
        if (approved == null)
        {
            // 人工评分：按分数阈值更新该岗位投递状态，不推进候选人状态（供 AI 评估失败的投递使用）；
            // 仅允许处于初筛段(0待筛选/1初筛通过)的投递被评分，淘汰(2)及后续环节不可被改回
            int status = currentScore >= PASS_THRESHOLD ? 1 : 2;
            if (screeningMapper.updateApplicationByCandidate(positionId, resultId, currentScore, status,
                    List.of(0, 1)) == 0)
                throw new ServiceException("该岗位投递已淘汰或已进入后续环节，无法修改初筛评分");
            result.put("applicationStatus", status);
            result.put("message", "已保存人工评分 " + currentScore + " 分，该岗位投递状态更新为"
                    + (status == 1 ? "通过初筛" : "初筛淘汰") + "；候选人状态保持不变，可在人才库继续跟进");
            return result;
        }
        if (Boolean.TRUE.equals(approved))
        {
            // 先校验投递仍处于初筛段，再推进候选人状态，避免出现“投递未变、候选人却已推进”的割裂
            if (positionId != null)
            {
                int rows = currentScore == null
                        ? screeningMapper.updateApplicationStatusByCandidate(positionId, resultId, 1, List.of(0, 1))
                        : screeningMapper.updateApplicationByCandidate(positionId, resultId, currentScore, 1, List.of(0, 1));
                if (rows == 0) throw new ServiceException("该岗位投递已淘汰或已进入后续环节，无法重复复核");
                result.put("applicationStatus", 1);
            }
            // 复核通过推进为「初筛通过」(1)，是否进入面试由约面环节写 2；已淘汰/已录用不可回退
            if (!talStatusService.change(resultId, TalStatusService.TAL_SCREENED, List.of(0, 1), positionId,
                    null, "HR复核通过", userId))
                throw new ServiceException("候选人已淘汰或已录用，状态不可回退");
            result.put("message", positionId == null
                    ? "已确认通过，候选人状态推进为待面试，等待流入面试邀约"
                    : "已确认通过，该岗位投递状态更新为通过初筛，候选人状态推进为待面试，等待流入面试邀约");
        }
        else
        {
            if (positionId != null)
            {
                // 驳回时同步当前总分，避免投递匹配度与 AI 报告分数不一致；已进入后续环节的投递不可再被驳回
                int rows = currentScore == null
                        ? screeningMapper.updateApplicationStatusByCandidate(positionId, resultId, 2, List.of(0, 1, 2))
                        : screeningMapper.updateApplicationByCandidate(positionId, resultId, currentScore, 2, List.of(0, 1, 2));
                if (rows == 0) throw new ServiceException("该岗位投递已进入后续环节，无法驳回");
                result.put("applicationStatus", 2);
            }
            // 初筛驳回即进入淘汰终态，归档来源记为初筛淘汰(4)，日志与流程实例终止由状态机统一处理
            if (!talStatusService.change(resultId, TalStatusService.TAL_REJECTED, List.of(0, 1), positionId,
                    4, "初筛未通过", userId))
                throw new ServiceException("候选人已淘汰或已录用，状态不可变更");
            result.put("message", positionId == null
                    ? "已驳回，候选人状态更新为已淘汰并归档人才库"
                    : "已驳回，该岗位投递状态更新为初筛淘汰，候选人状态更新为已淘汰并归档人才库");
        }
        return result;
    }

    /** 把 HR 调整后的总分写入该岗位该候选人的 AI 分析报告，维度明细保持不变。 */
    private void writeAdjustedReport(Long companyId, Long positionId, Long talId, double score)
    {
        Map<String, Object> row = screeningMapper.selectAnalysis(companyId, positionId, talId);
        if (row == null || row.get("report") == null)
        {
            // AI 评估失败（无分析记录）时创建人工评分记录，让 HR 打分有据可查
            Map<String, Object> manual = new LinkedHashMap<>();
            manual.put("resultId", talId);
            manual.put("positionId", positionId);
            manual.put("resumeId", screeningMapper.selectApplicationResume(companyId, positionId, talId));
            manual.put("source", "manual");
            manual.put("manual", true);
            manual.put("totalScore", score);
            manual.put("adjustedTotalScore", score);
            manual.put("hrAdjusted", true);
            manual.put("recommendation", "该候选人未完成 AI 评估，当前分数由 HR 人工评分录入");
            manual.put("companyId", companyId);
            manual.put("report", JSON.toJSONString(manual));
            screeningMapper.saveAnalysis(manual);
            return;
        }
        com.alibaba.fastjson2.JSONObject report = JSON.parseObject(row.get("report").toString());
        report.put("adjustedTotalScore", score);
        report.put("hrAdjusted", true);
        screeningMapper.updateAnalysisReport(companyId, positionId, talId, JSON.toJSONString(report));
    }

    private Map<String, Object> requirePosition(Long companyId, Long positionId)
    {
        if (positionId == null || positionId <= 0) throw new ServiceException("岗位ID不能为空");
        Map<String, Object> job = screeningMapper.selectPosition(companyId, positionId);
        if (job == null) throw new ServiceException("岗位不存在或无权访问");
        return new LinkedHashMap<>(job);
    }

    private void requireCandidate(Long companyId, Long resultId)
    {
        if (resultId == null || screeningMapper.selectOwnedCandidate(companyId, resultId) == null)
            throw new ServiceException("候选人不存在或无权访问");
    }

    /** 数值型字段兼容 Number 与数字字符串，非法值返回 null。 */
    private Double asDouble(Object value)
    {
        if (value instanceof Number number) return Double.isFinite(number.doubleValue()) ? number.doubleValue() : null;
        if (value == null) return null;
        try { return Double.valueOf(value.toString().trim()); }
        catch (NumberFormatException error) { return null; }
    }

    private int asInt(Object value)
    {
        if (value instanceof Number number) return number.intValue();
        if (value == null) return 0;
        try { return Integer.parseInt(value.toString().trim()); }
        catch (NumberFormatException error) { return 0; }
    }

    private Long resolveCompanyId(Long userId)
    {
        // This is a scalar authorization lookup with its own LIMIT 1, never a paginated query.
        // Discard stale thread-local pagination before it can append another LIMIT.
        PageUtils.clearPage();
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        if (companyId == null) throw new ServiceException("当前账号未绑定企业");
        return companyId;
    }
}
