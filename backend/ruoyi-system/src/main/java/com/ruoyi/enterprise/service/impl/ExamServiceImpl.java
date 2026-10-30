package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.mapper.ExamMapper;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.IExamService;
import com.ruoyi.enterprise.service.TalStatusService;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.service.EmailService;

/**
 * 企业端 - 在线笔试配置服务实现
 *
 * <p>题库 CRUD（平台共享）；试卷组卷支持 manual（人工选题）与 random（按题型/难度/
 * 技能标签规则随机抽题）两种模式，规则存 epa_rule_json；考试安排承载时长（取自试卷）、
 * 次数、开考/截止、通过阈值、双机位与交卷规则，状态按时间自动流转。</p>
 * <p>企业隔离：试卷与考试安排经 t_pos.pos_company_id 校验，越权统一"试卷不存在或无权访问"。</p>
 *
 * @author enterprise
 */
@Service
public class ExamServiceImpl implements IExamService
{
    /** 选择题题型（1-单选，2-多选，3-判断）：必须提供选项 */
    private static final int TYPE_MIN = 1;
    private static final int TYPE_MAX = 5;

    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Autowired
    private ExamMapper examMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Autowired
    private EmailService emailService;

    @Autowired
    private ScreeningMapper screeningMapper;

    @Autowired
    private TalStatusService talStatusService;

    // ==================== 题库 ====================

    @Override
    public List<Map<String, Object>> listQuestions(Integer type, Integer difficulty,
            String skillTag, String keyword, Integer pageNum, Integer pageSize)
    {
        PageUtils.startPage(pageNum, pageSize);
        List<Map<String, Object>> list = examMapper.selectQuestionList(type, difficulty, skillTag, keyword);
        for (Map<String, Object> item : list)
        {
            item.put("options", parseJson(item.get("optionsJson")));
        }
        return list;
    }

    @Override
    public Map<String, Object> getQuestion(Long questionId)
    {
        Map<String, Object> question = examMapper.selectQuestionById(questionId);
        if (question == null)
        {
            throw new ServiceException("题目不存在");
        }
        question.put("options", parseJson(question.get("optionsJson")));
        return question;
    }

    @Override
    public Long saveQuestion(Map<String, Object> body)
    {
        Map<String, Object> params = buildQuestionParams(body, null);
        examMapper.insertQuestion(params);
        long id = examMapper.selectLastQuestionId();
        return id == 0 ? null : id;
    }

    @Override
    public void updateQuestion(Long questionId, Map<String, Object> body)
    {
        if (examMapper.selectQuestionById(questionId) == null)
        {
            throw new ServiceException("题目不存在");
        }
        Map<String, Object> params = buildQuestionParams(body, questionId);
        examMapper.updateQuestion(params);
    }

    @Override
    public void deleteQuestion(Long questionId)
    {
        if (examMapper.selectQuestionById(questionId) == null)
        {
            throw new ServiceException("题目不存在");
        }
        examMapper.deleteQuestion(questionId);
    }

    private Map<String, Object> buildQuestionParams(Map<String, Object> body, Long id)
    {
        Integer type = asInt(body.get("type"), null);
        String content = asString(body.get("content"));
        String answer = asString(body.get("answer"));
        BigDecimal score = asDecimal(body.get("score"));
        if (type == null || type < TYPE_MIN || type > TYPE_MAX)
        {
            throw new ServiceException("题型无效（1-单选，2-多选，3-判断，4-简答，5-编程）");
        }
        if (StringUtils.isEmpty(content))
        {
            throw new ServiceException("题干不能为空");
        }
        if (StringUtils.isEmpty(answer))
        {
            throw new ServiceException("标准答案不能为空");
        }
        if (score == null || score.compareTo(BigDecimal.ZERO) <= 0)
        {
            throw new ServiceException("分值必须大于0");
        }
        Object options = body.get("options");
        String optionsJson = options == null ? null
                : (options instanceof String ? (String) options : JSON.toJSONString(options));
        if (type <= 3 && StringUtils.isEmpty(optionsJson))
        {
            throw new ServiceException("选择题必须提供选项");
        }
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("id", id);
        params.put("type", type);
        params.put("content", content);
        params.put("optionsJson", optionsJson);
        params.put("answer", answer);
        params.put("score", score);
        params.put("difficulty", asInt(body.get("difficulty"), 2));
        params.put("skillTag", asString(body.get("skillTag")));
        return params;
    }

    // ==================== 试卷 ====================

    @Override
    public List<Map<String, Object>> listPapers(Long userId, Long positionId)
    {
        List<Map<String, Object>> list = examMapper.selectPaperList(resolveCompanyId(userId), positionId);
        for (Map<String, Object> item : list)
        {
            item.put("rule", parseJson(item.get("ruleJson")));
        }
        return list;
    }

    @Override
    public Map<String, Object> getPaper(Long userId, Long paperId)
    {
        Map<String, Object> paper = requirePaper(resolveCompanyId(userId), paperId);
        paper.put("rule", parseJson(paper.get("ruleJson")));
        List<Map<String, Object>> questions = examMapper.selectPaperQuestions(paperId);
        for (Map<String, Object> q : questions)
        {
            q.put("options", parseJson(q.get("optionsJson")));
        }
        paper.put("questions", questions);
        return paper;
    }

    @Override
    public Long createPaper(Long userId, Map<String, Object> body)
    {
        Long companyId = resolveCompanyId(userId);
        Long positionId = asLong(body.get("positionId"));
        if (positionId == null || examMapper.countPosition(companyId, positionId) == 0)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        String name = asString(body.get("name"));
        Integer durationMin = asInt(body.get("durationMin"), null);
        if (StringUtils.isEmpty(name))
        {
            throw new ServiceException("试卷名称不能为空");
        }
        if (durationMin == null || durationMin <= 0)
        {
            throw new ServiceException("考试时长（分钟）必须大于0");
        }
        String mode = asString(body.get("mode"));
        BigDecimal totalScore;
        String ruleJson = null;
        List<Map<String, Object>> selected = new ArrayList<>();
        if ("random".equals(mode))
        {
            Map<String, Object> rule = asMap(body.get("rule"));
            totalScore = validateRandomRule(rule);
            ruleJson = JSON.toJSONString(rule);
        }
        else
        {
            selected = validateManualQuestions(body.get("questions"));
            totalScore = sumScore(selected);
        }
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("name", name);
        params.put("positionId", positionId);
        params.put("totalScore", totalScore);
        params.put("durationMin", durationMin);
        params.put("ruleJson", ruleJson);
        examMapper.insertPaper(params);
        Long paperId = (long) examMapper.selectLastPaperId();
        for (int i = 0; i < selected.size(); i++)
        {
            Map<String, Object> q = selected.get(i);
            examMapper.insertPaperQuestion(paperId, asLong(q.get("questionId")),
                    asDecimal(q.get("score")), i + 1);
        }
        return paperId;
    }

    @Override
    public void updatePaper(Long userId, Long paperId, Map<String, Object> body)
    {
        Map<String, Object> paper = requirePaper(resolveCompanyId(userId), paperId);
        String name = asString(body.get("name"));
        Integer durationMin = asInt(body.get("durationMin"), null);
        if (StringUtils.isEmpty(name))
        {
            throw new ServiceException("试卷名称不能为空");
        }
        if (durationMin == null || durationMin <= 0)
        {
            throw new ServiceException("考试时长（分钟）必须大于0");
        }
        String mode = asString(body.get("mode"));
        BigDecimal totalScore;
        String ruleJson = null;
        List<Map<String, Object>> selected = new ArrayList<>();
        if ("random".equals(mode))
        {
            Map<String, Object> rule = asMap(body.get("rule"));
            totalScore = validateRandomRule(rule);
            ruleJson = JSON.toJSONString(rule);
        }
        else
        {
            selected = validateManualQuestions(body.get("questions"));
            totalScore = sumScore(selected);
        }
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("id", paperId);
        params.put("name", name);
        params.put("totalScore", totalScore);
        params.put("durationMin", durationMin);
        params.put("ruleJson", ruleJson);
        params.put("status", asInt(body.get("status"), asInt(paper.get("status"), 1)));
        examMapper.updatePaper(params);
        examMapper.deletePaperQuestions(paperId);
        for (int i = 0; i < selected.size(); i++)
        {
            Map<String, Object> q = selected.get(i);
            examMapper.insertPaperQuestion(paperId, asLong(q.get("questionId")),
                    asDecimal(q.get("score")), i + 1);
        }
    }

    @Override
    public void deletePaper(Long userId, Long paperId)
    {
        requirePaper(resolveCompanyId(userId), paperId);
        if (examMapper.countActiveSchedulesByPaper(paperId) > 0)
        {
            throw new ServiceException("该试卷存在待生效或进行中的考试安排，不能删除");
        }
        examMapper.deletePaper(resolveCompanyId(userId), paperId);
    }

    @Override
    public Map<String, Object> previewDraw(Map<String, Object> rule)
    {
        List<Map<String, Object>> rules = asRuleList(rule);
        List<Long> excludeIds = new ArrayList<>();
        List<Map<String, Object>> drawn = new ArrayList<>();
        BigDecimal total = BigDecimal.ZERO;
        for (Map<String, Object> item : rules)
        {
            Integer type = asInt(item.get("type"), null);
            Integer difficulty = asInt(item.get("difficulty"), null);
            String skillTag = asString(item.get("skillTag"));
            int count = asInt(item.get("count"), 0);
            BigDecimal score = asDecimal(item.get("score"));
            if (count <= 0 || score == null)
            {
                throw new ServiceException("抽题规则每题数量与分值必须大于0");
            }
            List<Map<String, Object>> picked = examMapper.drawQuestions(type, difficulty, skillTag,
                    excludeIds.isEmpty() ? null : excludeIds, count);
            if (picked.size() < count)
            {
                throw new ServiceException("题库中满足条件的题目不足（需 " + count + " 题，仅 "
                        + picked.size() + " 题）");
            }
            for (Map<String, Object> q : picked)
            {
                q.put("score", score);
                q.put("options", parseJson(q.get("optionsJson")));
                excludeIds.add(asLong(q.get("questionId")));
                drawn.add(q);
                total = total.add(score);
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("questions", drawn);
        result.put("questionCount", drawn.size());
        result.put("totalScore", total);
        return result;
    }

    /** 校验随机抽题规则并返回预计总分 */
    private BigDecimal validateRandomRule(Map<String, Object> rule)
    {
        List<Map<String, Object>> rules = asRuleList(rule);
        if (rules.isEmpty())
        {
            throw new ServiceException("随机抽题规则不能为空");
        }
        BigDecimal total = BigDecimal.ZERO;
        List<String> pickedKeys = new ArrayList<>();
        for (Map<String, Object> item : rules)
        {
            Integer type = asInt(item.get("type"), null);
            Integer difficulty = asInt(item.get("difficulty"), null);
            String skillTag = asString(item.get("skillTag"));
            int count = asInt(item.get("count"), 0);
            BigDecimal score = asDecimal(item.get("score"));
            if (type == null || count <= 0 || score == null || score.compareTo(BigDecimal.ZERO) <= 0)
            {
                throw new ServiceException("抽题规则需包含题型、每题数量与每题分值");
            }
            int available = examMapper.countDrawQuestions(type, difficulty, skillTag);
            if (available < count)
            {
                throw new ServiceException("题型 " + type + " 可用题目不足（需 " + count + " 题，仅 "
                        + available + " 题）");
            }
            total = total.add(score.multiply(BigDecimal.valueOf(count)));
            pickedKeys.add(type + ":" + difficulty + ":" + skillTag);
        }
        if (pickedKeys.size() > 10)
        {
            throw new ServiceException("抽题规则分组过多");
        }
        return total;
    }

    /** 校验人工选题清单，返回规范化 [{questionId, score}] */
    private List<Map<String, Object>> validateManualQuestions(Object raw)
    {
        List<Map<String, Object>> questions = asList(raw);
        if (questions.isEmpty())
        {
            throw new ServiceException("人工组卷必须选择题");
        }
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> q : questions)
        {
            Long questionId = asLong(q.get("questionId"));
            BigDecimal score = asDecimal(q.get("score"));
            if (questionId == null || examMapper.selectQuestionById(questionId) == null)
            {
                throw new ServiceException("题目不存在：" + questionId);
            }
            if (score == null || score.compareTo(BigDecimal.ZERO) <= 0)
            {
                throw new ServiceException("每题分值必须大于0");
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("questionId", questionId);
            item.put("score", score);
            result.add(item);
        }
        return result;
    }

    private BigDecimal sumScore(List<Map<String, Object>> questions)
    {
        BigDecimal total = BigDecimal.ZERO;
        for (Map<String, Object> q : questions)
        {
            total = total.add((BigDecimal) q.get("score"));
        }
        return total;
    }

    // ==================== 考试安排 ====================

    @Override
    public List<Map<String, Object>> listSchedules(Long userId, Long positionId, Integer status,
            Integer pageNum, Integer pageSize)
    {
        // 先解析公司ID再开启分页，避免 PageHelper 把 LIMIT 附加到公司查询 SQL
        Long companyId = resolveCompanyId(userId);
        examMapper.syncScheduleStatuses();
        PageUtils.startPage(pageNum, pageSize);
        List<Map<String, Object>> list = examMapper.selectScheduleList(companyId, positionId, status);
        for (Map<String, Object> item : list)
        {
            decorateSchedule(item);
        }
        return list;
    }

    @Override
    public Map<String, Object> getSchedule(Long userId, Long scheduleId)
    {
        Map<String, Object> schedule = examMapper.selectScheduleById(resolveCompanyId(userId), scheduleId);
        if (schedule == null)
        {
            throw new ServiceException("考试安排不存在或无权访问");
        }
        decorateSchedule(schedule);
        return schedule;
    }

    @Override
    public Long createSchedule(Long userId, Map<String, Object> body)
    {
        Long companyId = resolveCompanyId(userId);
        Long positionId = asLong(body.get("positionId"));
        if (positionId == null || examMapper.countPosition(companyId, positionId) == 0)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        Map<String, Object> scheduleParams = buildScheduleParams(body, null, companyId);
        examMapper.insertSchedule(scheduleParams);
        return (long) examMapper.selectLastScheduleId();
    }

    @Override
    public void updateSchedule(Long userId, Long scheduleId, Map<String, Object> body)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> existing = requireSchedule(companyId, scheduleId);
        int status = asInt(existing.get("status"), 0);
        if (status >= 2)
        {
            throw new ServiceException("已结束或已取消的考试安排不能修改");
        }
        Map<String, Object> params = buildScheduleParams(body, scheduleId, companyId);
        examMapper.updateSchedule(params);
    }

    @Override
    public void cancelSchedule(Long userId, Long scheduleId)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> existing = requireSchedule(companyId, scheduleId);
        int status = asInt(existing.get("status"), 0);
        if (status >= 2)
        {
            throw new ServiceException("考试安排已结束或已取消");
        }
        examMapper.updateScheduleStatus(scheduleId, 3);
    }

    private Map<String, Object> buildScheduleParams(Map<String, Object> body, Long id, Long companyId)
    {
        Long paperId = asLong(body.get("paperId"));
        Map<String, Object> paper = requirePaper(companyId, paperId);
        Long positionId = asLong(body.get("positionId"));
        if (positionId == null || !String.valueOf(positionId).equals(String.valueOf(paper.get("positionId"))))
        {
            throw new ServiceException("考试安排岗位与试卷关联岗位不一致");
        }
        String startAt = normalizeTime(asString(body.get("startAt")));
        String endAt = normalizeTime(asString(body.get("endAt")));
        if (startAt == null || endAt == null)
        {
            throw new ServiceException("开考/截止时间格式应为 yyyy-MM-dd HH:mm[:ss]");
        }
        if (endAt.compareTo(startAt) <= 0)
        {
            throw new ServiceException("截止时间必须晚于开考时间");
        }
        Integer maxAttempts = asInt(body.get("maxAttempts"), 1);
        BigDecimal passThreshold = asDecimal(body.get("passThreshold"));
        if (maxAttempts == null || maxAttempts < 1)
        {
            throw new ServiceException("最大考试次数至少为1");
        }
        if (passThreshold == null || passThreshold.compareTo(BigDecimal.ZERO) <= 0)
        {
            throw new ServiceException("通过阈值必须大于0");
        }
        BigDecimal totalScore = new BigDecimal(String.valueOf(paper.get("totalScore")));
        if (passThreshold.compareTo(totalScore) > 0)
        {
            throw new ServiceException("通过阈值不能超过试卷总分 " + totalScore);
        }
        Object dual = body.get("dualCameraConfig");
        Object submit = body.get("submitRule");
        Object autoFlow = body.get("autoFlow");
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("id", id);
        params.put("positionId", positionId);
        params.put("paperId", paperId);
        params.put("startAt", startAt);
        params.put("endAt", endAt);
        params.put("maxAttempts", maxAttempts);
        params.put("passThreshold", passThreshold);
        params.put("forceDualCamera", asInt(body.get("forceDualCamera"), 0));
        params.put("dualCameraConfig", dual == null ? null
                : (dual instanceof String ? dual : JSON.toJSONString(dual)));
        params.put("submitRule", submit == null ? null
                : (submit instanceof String ? submit : JSON.toJSONString(submit)));
        params.put("autoFlow", autoFlow == null ? null
                : (autoFlow instanceof String ? autoFlow : JSON.toJSONString(autoFlow)));
        return params;
    }

    private void decorateSchedule(Map<String, Object> item)
    {
        item.put("dualCameraConfig", parseJson(item.get("dualCameraConfig")));
        item.put("submitRule", parseJson(item.get("submitRule")));
        item.put("notifyConfig", parseJson(item.get("notifyConfig")));
        item.put("autoFlow", parseJson(item.get("autoFlow")));
    }

    // ==================== 笔试通知 ====================

    /** 允许的通知渠道 */
    private static final List<String> NOTIFY_CHANNELS = java.util.Arrays.asList("email", "inapp");

    @Override
    public void saveNotifyConfig(Long userId, Long scheduleId, Map<String, Object> body)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> schedule = requireSchedule(companyId, scheduleId);
        if (asInt(schedule.get("status"), 0) >= 2)
        {
            throw new ServiceException("已结束或已取消的考试安排不能修改通知配置");
        }
        List<String> channels = normalizeChannels(body.get("channels"));
        Map<String, Object> config = new LinkedHashMap<>();
        config.put("channels", channels);
        config.put("title", asString(body.get("title")));
        config.put("content", asString(body.get("content")));
        config.put("examUrl", asString(body.get("examUrl")));
        examMapper.updateScheduleNotifyConfig(scheduleId, JSON.toJSONString(config));
    }

    @Override
    public List<Map<String, Object>> listNotifyTargets(Long userId, Long scheduleId)
    {
        Long companyId = resolveCompanyId(userId);
        requireSchedule(companyId, scheduleId);
        return examMapper.selectNotifyTargets(companyId, scheduleId);
    }

    @Override
    public Map<String, Object> sendNotify(Long userId, Long scheduleId, Map<String, Object> body)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> schedule = requireSchedule(companyId, scheduleId);
        if (asInt(schedule.get("status"), 0) >= 2)
        {
            throw new ServiceException("考试安排已结束或已取消，不能发送通知");
        }
        Map<String, Object> saved = asMap(parseJson(schedule.get("notifyConfig")));
        List<String> channels = body != null && body.containsKey("channels")
                ? normalizeChannels(body.get("channels")) : normalizeChannels(saved.get("channels"));
        String title = pick(asString(body == null ? null : body.get("title")),
                asString(saved.get("title")), "笔试通知 - {positionTitle}");
        String content = pick(asString(body == null ? null : body.get("content")),
                asString(saved.get("content")),
                "候选人{candidateName}您好：您受邀参加岗位「{positionTitle}」的在线笔试《{paperName}》，"
                        + "作答时间 {startAt} ~ {endAt}，试卷时长 {durationMin} 分钟。请在截止前进入笔试作答：{examUrl}");
        String examUrl = pick(asString(body == null ? null : body.get("examUrl")),
                asString(saved.get("examUrl")), "/exam?scheduleId=" + scheduleId);

        List<Map<String, Object>> targets = examMapper.selectNotifyTargets(companyId, scheduleId);
        if (body != null && body.get("candidateIds") instanceof List && !((List<?>) body.get("candidateIds")).isEmpty())
        {
            List<Long> candidateIds = new ArrayList<>();
            for (Object raw : (List<?>) body.get("candidateIds"))
            {
                Long id = asLong(raw);
                if (id != null && !candidateIds.contains(id))
                {
                    candidateIds.add(id);
                }
            }
            if (!candidateIds.isEmpty())
            {
                List<Map<String, Object>> filtered = new ArrayList<>();
                for (Map<String, Object> t : targets)
                {
                    if (candidateIds.contains(asLong(t.get("talId"))))
                    {
                        filtered.add(t);
                    }
                }
                targets = filtered;
            }
        }

        List<Map<String, Object>> results = new ArrayList<>();
        int sentCount = 0;
        for (Map<String, Object> target : targets)
        {
            Map<String, Object> vars = new LinkedHashMap<>();
            vars.put("candidateName", String.valueOf(target.getOrDefault("name", "")));
            vars.put("positionTitle", String.valueOf(schedule.getOrDefault("positionTitle", "")));
            vars.put("paperName", String.valueOf(schedule.getOrDefault("paperName", "")));
            vars.put("startAt", String.valueOf(schedule.getOrDefault("startAt", "")));
            vars.put("endAt", String.valueOf(schedule.getOrDefault("endAt", "")));
            vars.put("durationMin", String.valueOf(schedule.getOrDefault("durationMin", "")));
            vars.put("examUrl", examUrl);
            String renderTitle = renderTemplate(title, vars);
            String renderContent = renderTemplate(content, vars);

            Map<String, Object> channelsResult = new LinkedHashMap<>();
            if (channels.contains("email"))
            {
                String email = asString(target.get("email"));
                if (StringUtils.isEmpty(email))
                {
                    channelsResult.put("email", "skipped_no_email");
                }
                else
                {
                    channelsResult.put("email",
                            emailService.sendSimpleMail(email, renderTitle, renderContent) ? "sent" : "failed");
                }
            }
            else
            {
                channelsResult.put("email", "not_selected");
            }
            if (channels.contains("inapp"))
            {
                examMapper.insertExamNotifyMessage(asLong(target.get("userId")), renderTitle, renderContent);
                channelsResult.put("inapp", "sent");
            }
            else
            {
                channelsResult.put("inapp", "not_selected");
            }
            sentCount++;
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("talId", target.get("talId"));
            item.put("name", target.get("name"));
            item.put("email", target.get("email"));
            item.put("channels", channelsResult);
            results.add(item);
        }
        // 笔试通知发出后立即把对应岗位投递状态同步为「待笔试」
        Long schedulePositionId = asLong(schedule.get("positionId"));
        if (schedulePositionId != null)
        {
            for (Map<String, Object> item : results)
            {
                Long talId = asLong(item.get("talId"));
                if (talId != null && screeningMapper.advanceApplicationStatus(schedulePositionId, talId, 4,
                        List.of(0, 1, 2, 3)) > 0)
                {
                    // 仅对仍在有效流程中的投递推进候选人状态，已淘汰/已撤回投递不参与笔试
                    talStatusService.change(talId, TalStatusService.TAL_PENDING_EXAM,
                            List.of(0, 1, 2, 5, 6, 7, 8, 9), schedulePositionId, null, "已发送笔试通知", userId);
                }
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("total", targets.size());
        result.put("sent", sentCount);
        result.put("channels", channels);
        result.put("results", results);
        return result;
    }

    private List<String> normalizeChannels(Object raw)
    {
        List<String> channels = new ArrayList<>();
        if (raw instanceof List)
        {
            for (Object item : (List<?>) raw)
            {
                String value = asString(item);
                if (NOTIFY_CHANNELS.contains(value) && !channels.contains(value))
                {
                    channels.add(value);
                }
            }
        }
        if (channels.isEmpty())
        {
            channels.add("inapp");
        }
        return channels;
    }

    private String pick(String first, String second, String fallback)
    {
        if (StringUtils.isNotEmpty(first))
        {
            return first;
        }
        return StringUtils.isNotEmpty(second) ? second : fallback;
    }

    private String renderTemplate(String template, Map<String, Object> vars)
    {
        String text = template;
        for (Map.Entry<String, Object> entry : vars.entrySet())
        {
            text = text.replace("{" + entry.getKey() + "}", entry.getValue() == null ? "" : String.valueOf(entry.getValue()));
        }
        return text;
    }

    // ==================== 通用 ====================

    private Map<String, Object> requirePaper(Long companyId, Long paperId)
    {
        Map<String, Object> paper = paperId == null ? null : examMapper.selectPaperById(companyId, paperId);
        if (paper == null)
        {
            throw new ServiceException("试卷不存在或无权访问");
        }
        return paper;
    }

    private Map<String, Object> requireSchedule(Long companyId, Long scheduleId)
    {
        Map<String, Object> schedule = scheduleId == null ? null : examMapper.selectScheduleById(companyId, scheduleId);
        if (schedule == null)
        {
            throw new ServiceException("考试安排不存在或无权访问");
        }
        return schedule;
    }

    /** 解析当前用户所属公司（未绑定默认公司1，与其他企业端模块一致） */
    private Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }

    private String normalizeTime(String value)
    {
        if (StringUtils.isEmpty(value))
        {
            return null;
        }
        String text = value.trim().replace('T', ' ');
        try
        {
            if (text.length() == 16)
            {
                text = text + ":00";
            }
            LocalDateTime.parse(text, TIME_FORMAT);
            return text;
        }
        catch (Exception e)
        {
            return null;
        }
    }

    private Object parseJson(Object value)
    {
        if (value == null || StringUtils.isEmpty(String.valueOf(value)))
        {
            return null;
        }
        try
        {
            return JSON.parse(String.valueOf(value));
        }
        catch (Exception e)
        {
            return value;
        }
    }

    private Long asLong(Object v)
    {
        if (v == null)
        {
            return null;
        }
        if (v instanceof Number)
        {
            return ((Number) v).longValue();
        }
        String s = v.toString().trim();
        return s.isEmpty() ? null : Long.valueOf(s);
    }

    private Integer asInt(Object v, Integer defaultValue)
    {
        if (v == null)
        {
            return defaultValue;
        }
        if (v instanceof Number)
        {
            return ((Number) v).intValue();
        }
        String s = v.toString().trim();
        return s.isEmpty() ? defaultValue : Integer.valueOf(s);
    }

    private BigDecimal asDecimal(Object v)
    {
        if (v == null)
        {
            return null;
        }
        if (v instanceof BigDecimal)
        {
            return (BigDecimal) v;
        }
        String s = v.toString().trim();
        return s.isEmpty() ? null : new BigDecimal(s);
    }

    private String asString(Object v)
    {
        return v == null ? null : String.valueOf(v).trim();
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> asMap(Object v)
    {
        return v instanceof Map ? (Map<String, Object>) v : new LinkedHashMap<>();
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> asList(Object v)
    {
        if (v == null)
        {
            return new ArrayList<>();
        }
        if (v instanceof List)
        {
            List<Map<String, Object>> result = new ArrayList<>();
            for (Object item : (List<Object>) v)
            {
                result.add(asMap(item));
            }
            return result;
        }
        if (v instanceof String)
        {
            Object parsed = parseJson(v);
            return parsed instanceof List ? asList(parsed) : new ArrayList<>();
        }
        return new ArrayList<>();
    }

    private List<Map<String, Object>> asRuleList(Map<String, Object> rule)
    {
        return asList(rule == null ? null : rule.get("rules"));
    }
}
