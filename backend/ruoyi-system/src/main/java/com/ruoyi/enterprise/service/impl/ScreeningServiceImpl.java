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
import org.springframework.transaction.support.TransactionTemplate;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.IScreeningService;
import com.ruoyi.enterprise.service.screening.ScreeningAiEvaluator;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.service.app.pdf.ResumePdfParser;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;

/** Real, evidence-based AI evaluation. Running tasks never hold a database transaction across HTTP calls. */
@Service
public class ScreeningServiceImpl implements IScreeningService
{
    @Autowired private ScreeningMapper screeningMapper;
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
        task.put("topN", topN == null ? 20 : topN);
        return task;
    }

    @Override
    public Map<String, Object> triggerScreeningAsync(Long userId, Long positionId, Integer topN)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> job = requirePosition(companyId, positionId);
        if (topN != null && (topN < 1 || topN > 200)) throw new ServiceException("短名单人数须为1至200");
        List<Map<String, Object>> candidates = screeningMapper.selectCandidatesByPosition(positionId);
        if (candidates.isEmpty()) throw new ServiceException("该岗位暂无可筛选的求职者");
        Map<String, Object> current = screeningMapper.selectTaskStatus(companyId, positionId);
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
            workers.execute(() -> runScreening(companyId, positionId, runId, job, candidates));
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
            List<Map<String, Object>> candidates)
    {
        int completed = 0;
        try
        {
            long deadline = System.nanoTime() + TimeUnit.MINUTES.toNanos(10);
            List<Map<String, Object>> analyses = new ArrayList<>();
            for (int start = 0; start < candidates.size(); start += 3)
            {
                if (Thread.currentThread().isInterrupted() || System.nanoTime() > deadline)
                    throw new ServiceException("AI筛选任务超时或已中断，原有结果未变更");
                List<Map<String, Object>> batch = new ArrayList<>();
                for (Map<String, Object> candidate : candidates.subList(start, Math.min(start + 3, candidates.size())))
                    batch.add(resumeEvidence(candidate));
                analyses.addAll(evaluator.evaluate(job, batch));
                completed += batch.size();
                if (screeningMapper.updateTask(companyId, positionId, runId, "processing", completed, 0, null) == 0) return;
            }
            new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
                Map<String, Object> task = screeningMapper.lockTask(companyId, positionId);
                if (task == null || !runId.equals(task.get("runId"))) throw new ServiceException("AI筛选任务已被更新");
                Map<String, Object> currentJob = requirePosition(companyId, positionId);
                if (!java.util.Objects.equals(job.get("positionVersion"), currentJob.get("positionVersion")))
                    throw new ServiceException("分析期间岗位发生变化，请重新筛选，原有结果未变更");
                List<Map<String, Object>> currentCandidates = screeningMapper.selectCandidatesByPosition(positionId);
                int scored = 0;
                for (Map<String, Object> analysis : analyses)
                {
                    long id = ((Number)analysis.get("resultId")).longValue();
                    Map<String, Object> candidate = candidates.stream()
                            .filter(c -> Long.parseLong(c.get("talentId").toString()) == id).findFirst().orElseThrow();
                    Map<String, Object> latest = currentCandidates.stream()
                            .filter(c -> Long.parseLong(c.get("talentId").toString()) == id).findFirst().orElse(null);
                    if (latest == null || !java.util.Objects.equals(candidate.get("resumeId"), latest.get("resumeId"))
                            || !java.util.Objects.equals(candidate.get("resumeVersion"), latest.get("resumeVersion")))
                        throw new ServiceException("分析期间候选人或简历发生变化，请重新筛选，原有结果未变更");
                    analysis.put("positionId", positionId);
                    analysis.put("positionTitle", job.get("title"));
                    analysis.put("resumeId", candidate.get("resumeId"));
                    Map<String, Object> row = new LinkedHashMap<>(analysis);
                    row.put("companyId", companyId);
                    row.put("report", JSON.toJSONString(analysis));
                    screeningMapper.saveAnalysis(row);
                    screeningMapper.updateMatchedScore(id, (Double)analysis.get("totalScore"));
                    if (analysis.get("totalScore") != null) scored++;
                }
                screeningMapper.updateTask(companyId, positionId, runId, "completed", candidates.size(), scored, null);
            });
        }
        catch (RuntimeException error)
        {
            String message = error instanceof ServiceException ? error.getMessage() : "AI筛选失败，原有结果未变更，请稍后重试";
            try { screeningMapper.updateTask(companyId, positionId, runId, "failed", completed, 0, message); }
            catch (RuntimeException ignored) { /* No prompt, resume or database exception details may be logged. */ }
        }
        finally { capacity.release(); }
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
        for (Map<String, Object> candidate : candidates)
        {
            Long id = Long.valueOf(candidate.get("resultId").toString());
            Map<String, Object> analysis = readAnalysis(screeningMapper.selectAnalysis(companyId, taskId, id));
            // Old rule-based scores must never be presented as a completed AI evaluation.
            candidate.put("totalScore", null);
            for (String key : ScreeningAiEvaluator.WEIGHTS.keySet()) candidate.put(key, null);
            candidate.put("source", "not_analyzed");
            if (analysis != null) candidate.putAll(analysis);
        }
        candidates.sort(Comparator.comparing((Map<String, Object> c) ->
                c.get("totalScore") instanceof Number n ? n.doubleValue() : -1.0).reversed());
        return candidates;
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
        if (!"llm".equals(report.get("source"))) return null;
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
    public Map<String, Object> reviewResult(Long userId, Long resultId, Boolean approved, Double adjustScore)
    {
        requireCandidate(resolveCompanyId(userId), resultId);
        if (approved == null) throw new ServiceException("复核结论不能为空");
        if (adjustScore != null && (!Double.isFinite(adjustScore) || adjustScore < 0 || adjustScore > 100))
            throw new ServiceException("调整评分须为0至100");
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("resultId", resultId);
        result.put("approved", approved);
        if (Boolean.TRUE.equals(approved))
        {
            if (adjustScore != null)
            {
                double rounded = Math.round(adjustScore * 10.0) / 10.0;
                screeningMapper.updateMatchedScore(resultId, rounded);
                result.put("adjustScore", rounded);
            }
            if (screeningMapper.updateTalStatus(resultId, 1) == 0) throw new ServiceException("候选人不存在");
            result.put("message", "已确认通过，候选人状态推进为初筛通过，等待流入面试邀约");
        }
        else result.put("message", "已驳回，候选人保持在人才库待观察");
        return result;
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
