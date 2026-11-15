package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.domain.ProcessStageInstance;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.mapper.CandidateExamMapper;
import com.ruoyi.enterprise.mapper.ExamMapper;
import com.ruoyi.enterprise.service.ICandidateExamService;
import com.ruoyi.enterprise.service.IExamGradeService;
import com.ruoyi.enterprise.service.IExamMonitorService;
import com.ruoyi.enterprise.service.ProcessStageInstanceService;
import com.ruoyi.enterprise.service.TalStatusService;

/**
 * 候选人端 - 在线笔试服务实现
 *
 * <p>身份：登录用户经 t_tal.tal_user_id 解析候选人档案；仅可参加自己投递岗位对应的考试。
 * 开考：t_exam_record（schedule+candidate 唯一）首次开考置进行中并生成题目快照
 * （随机卷按规则抽题、人工卷按试卷选题，满分写入 ean_max_score），续考直接读快照。
 * 时限：deadline = min(开始时间+试卷时长, 安排截止时间)；超时按 submitRule.autoSubmit
 * 自动交卷（默认开启），关闭时记录作废（已缺考）。</p>
 *
 * @author enterprise
 */
@Service
public class CandidateExamServiceImpl implements ICandidateExamService
{
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Autowired
    private CandidateExamMapper candidateExamMapper;

    @Autowired
    private ExamMapper examMapper;

    @Autowired
    private IExamGradeService examGradeService;

    @Autowired
    private IExamMonitorService examMonitorService;

    @Autowired
    private ApplicationStatusMapper applicationStatusMapper;

    @Autowired
    private ProcessStageInstanceService processStageInstanceService;

    @Autowired
    private TalStatusService talStatusService;

    @Override
    public List<Map<String, Object>> listMyExams(Long userId)
    {
        requireTalent(userId);
        List<Map<String, Object>> list = candidateExamMapper.selectMyScheduleList(userId);
        for (Map<String, Object> item : list)
        {
            item.put("openNow", isOpenNow(asTime(item.get("startAt")), asTime(item.get("endAt"))));
        }
        return list;
    }

    @Override
    public Map<String, Object> getExamEntry(Long userId, Long scheduleId)
    {
        Map<String, Object> schedule = requireSchedule(userId, scheduleId);
        Object rule = parseJson(schedule.get("ruleJson"));
        schedule.put("rule", rule);
        schedule.put("submitRule", parseJson(schedule.get("submitRule")));
        int questionCount;
        if (rule instanceof Map && !((Map<?, ?>) rule).containsKey("rules"))
        {
            questionCount = 0;
            for (String key : LEGACY_TYPE_KEYS.keySet())
            {
                questionCount += asInt(((Map<?, ?>) rule).get(key), 0);
            }
        }
        else if (rule != null)
        {
            questionCount = 0;
            for (Map<String, Object> item : ruleList(rule))
            {
                Integer count = asInt(item.get("count"), 0);
                questionCount += count;
            }
        }
        else
        {
            questionCount = examMapper.selectPaperQuestions(asLong(schedule.get("paperId"))).size();
        }
        schedule.put("questionCount", questionCount);
        schedule.put("openNow", isOpenNow(asTime(schedule.get("startAt")), asTime(schedule.get("endAt"))));
        return schedule;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> prepareExam(Long userId, Long scheduleId)
    {
        Map<String, Object> schedule = requireSchedule(userId, scheduleId);
        int status = asInt(schedule.get("status"), 0);
        if (status == 3)
        {
            throw new ServiceException("该考试已取消");
        }
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startAt = asTime(schedule.get("startAt"));
        LocalDateTime endAt = asTime(schedule.get("endAt"));
        if (startAt != null && now.isBefore(startAt))
        {
            throw new ServiceException("考试尚未开始，开考时间 " + schedule.get("startAt"));
        }
        if (endAt != null && now.isAfter(endAt))
        {
            throw new ServiceException("考试已结束");
        }
        Long recordId = asLong(schedule.get("recordId"));
        if (recordId == null)
        {
            // 设备检测阶段只建未开始记录，开考时间留空，不占用答题时长
            Long talId = asLong(requireTalent(userId).get("talId"));
            candidateExamMapper.insertPrepRecord(scheduleId, talId);
            recordId = (long) candidateExamMapper.selectLastRecordId();
        }
        else
        {
            Map<String, Object> record = candidateExamMapper.selectRecordForCandidate(userId, recordId);
            int recordStatus = asInt(record.get("status"), 0);
            if (recordStatus == 2 || recordStatus == 4)
            {
                throw new ServiceException("本场考试已交卷");
            }
            if (recordStatus == 3)
            {
                throw new ServiceException("本次考试已作废（超时未交卷）");
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordId", recordId);
        result.put("forceDualCamera", schedule.get("forceDualCamera"));
        result.put("durationMin", schedule.get("durationMin"));
        result.put("startAt", schedule.get("startAt"));
        result.put("endAt", schedule.get("endAt"));
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> startOrResume(Long userId, Long scheduleId, String deviceInfo)
    {
        Map<String, Object> schedule = requireSchedule(userId, scheduleId);
        int status = asInt(schedule.get("status"), 0);
        if (status == 3)
        {
            throw new ServiceException("该考试已取消");
        }
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startAt = asTime(schedule.get("startAt"));
        LocalDateTime endAt = asTime(schedule.get("endAt"));
        if (startAt != null && now.isBefore(startAt))
        {
            throw new ServiceException("考试尚未开始，开考时间 " + schedule.get("startAt"));
        }

        Long recordId = asLong(schedule.get("recordId"));
        if (recordId != null)
        {
            Map<String, Object> record = candidateExamMapper.selectRecordForCandidate(userId, recordId);
            int recordStatus = asInt(record.get("status"), 0);
            if (recordStatus == 2 || recordStatus == 4)
            {
                // 已交卷但判分缺失（如判分异常中断）：补判一次
                if (recordStatus == 2 && record.get("passStatus") == null)
                {
                    tryGrade(recordId);
                    record = candidateExamMapper.selectRecordForCandidate(userId, recordId);
                }
                return submittedResult(record, false);
            }
            if (recordStatus == 3)
            {
                throw new ServiceException("本次考试已作废（超时未交卷）");
            }
            if (recordStatus == 0)
            {
                // 设备检测通过后正式开考：此时才开始计时并写入题目快照
                if (endAt != null && now.isAfter(endAt))
                {
                    throw new ServiceException("考试已结束");
                }
                requireDualCameraReady(recordId);
                candidateExamMapper.beginRecord(recordId);
                if (candidateExamMapper.selectRecordQuestions(recordId).isEmpty())
                {
                    snapshotQuestions(asLong(schedule.get("paperId")), parseJson(schedule.get("ruleJson")), recordId);
                }
                Long talId = asLong(requireTalent(userId).get("talId"));
                // 本轮笔试节点：开考 start（按 refId=recordId 幂等）；app_status 已由 HR 发通知时切到招聘中，这里不动
                openExamNode(recordId, talId, asLong(schedule.get("positionId")), userId);
                talStatusService.change(talId, TalStatusService.TAL_EXAM_TAKING,
                        List.of(0, 1, 2, 5, 6, 7, 8, 9), asLong(schedule.get("positionId")), null, "开始笔试", userId);
                record = candidateExamMapper.selectRecordForCandidate(userId, recordId);
                LocalDateTime startedDeadline = deadline(asTime(record.get("startAt")),
                        asInt(record.get("durationMin"), 0), endAt);
                return resumeResult(record, startedDeadline, now);
            }
            // 进行中：先判超时
            LocalDateTime deadline = deadline(asTime(record.get("startAt")),
                    asInt(record.get("durationMin"), 0), asTime(record.get("endAt")));
            if (deadline != null && !now.isBefore(deadline))
            {
                return expireRecord(userId, record);
            }
            requireDualCameraReady(recordId);
            return resumeResult(record, deadline, now);
        }

        if (endAt != null && now.isAfter(endAt))
        {
            throw new ServiceException("考试已结束");
        }
        // 强制双机位必须先完成设备检测并接入副机位，禁止直接开考
        if (asInt(schedule.get("forceDualCamera"), 0) == 1)
        {
            throw new ServiceException("本场考试要求双机位监考，请先完成设备检测并接入副机位");
        }
        // 首次开考：建记录 + 题目快照
        Long talId = asLong(requireTalent(userId).get("talId"));
        candidateExamMapper.insertRecord(scheduleId, talId, deviceInfo);
        recordId = (long) candidateExamMapper.selectLastRecordId();
        snapshotQuestions(asLong(schedule.get("paperId")), parseJson(schedule.get("ruleJson")), recordId);
        // 本轮笔试节点：开考 start；app_status 不动（HR 发通知时已切到招聘中）
        openExamNode(recordId, talId, asLong(schedule.get("positionId")), userId);
        talStatusService.change(talId, TalStatusService.TAL_EXAM_TAKING,
                List.of(0, 1, 2, 5, 6, 7, 8, 9), asLong(schedule.get("positionId")), null, "开始笔试", userId);

        Map<String, Object> record = candidateExamMapper.selectRecordForCandidate(userId, recordId);
        LocalDateTime deadline = deadline(now, asInt(record.get("durationMin"), 0), endAt);
        return resumeResult(record, deadline, now);
    }

    @Override
    public Map<String, Object> saveAnswers(Long userId, Long recordId, List<Map<String, Object>> answers)
    {
        Map<String, Object> record = requireActiveRecord(userId, recordId);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime deadline = deadline(asTime(record.get("startAt")),
                asInt(record.get("durationMin"), 0), asTime(record.get("endAt")));
        if (deadline != null && !now.isBefore(deadline))
        {
            // 超时到达的保存请求：先落库最后一次作答，再按规则自动交卷，避免最后一轮答案丢失
            persistAnswers(recordId, answers);
            Map<String, Object> expired = expireRecord(userId, record);
            expired.put("timeout", true);
            return expired;
        }
        int saved = persistAnswers(recordId, answers);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordId", recordId);
        result.put("saved", saved);
        result.put("remainingSec", remaining(deadline, now));
        result.put("savedAt", now.format(TIME_FORMAT));
        return result;
    }

    @Override
    public Map<String, Object> submit(Long userId, Long recordId, List<Map<String, Object>> answers)
    {
        Map<String, Object> record = requireActiveRecord(userId, recordId);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime deadline = deadline(asTime(record.get("startAt")),
                asInt(record.get("durationMin"), 0), asTime(record.get("endAt")));
        if (deadline != null && !now.isBefore(deadline))
        {
            // 超时到达后的交卷请求：先落库最后一次作答，再按自动交卷规则处理，保证幂等
            persistAnswers(recordId, answers);
            Map<String, Object> expired = expireRecord(userId, record);
            expired.put("timeout", true);
            return expired;
        }
        persistAnswers(recordId, answers);
        candidateExamMapper.updateRecordSubmitted(recordId);
        tryGrade(recordId);
        Map<String, Object> fresh = candidateExamMapper.selectRecordForCandidate(userId, recordId);
        return submittedResult(fresh, false);
    }

    /** 逐题落库作答内容，返回实际更新行数（无答案行时返回 0） */
    private int persistAnswers(Long recordId, List<Map<String, Object>> answers)
    {
        if (answers == null)
        {
            return 0;
        }
        int saved = 0;
        for (Map<String, Object> answer : answers)
        {
            Long questionId = asLong(answer.get("questionId"));
            if (questionId != null)
            {
                saved += candidateExamMapper.updateAnswerContent(recordId, questionId,
                        asString(answer.get("content")));
            }
        }
        return saved;
    }

    /** 交卷判分入口：失败不阻断交卷结果返回，续考时会补判一次 */
    private void tryGrade(Long recordId)
    {
        try
        {
            examGradeService.gradeOnSubmit(recordId);
        }
        catch (Exception e)
        {
            // 判分异常时记录保持"已交卷未评分"，下次进入页面自动补判
        }
    }

    // ==================== 内部逻辑 ====================

    private Map<String, Object> requireTalent(Long userId)
    {
        Map<String, Object> talent = candidateExamMapper.selectTalentByUser(userId);
        if (talent == null)
        {
            throw new ServiceException("候选人档案不存在，请先完善简历");
        }
        return talent;
    }

    private Map<String, Object> requireSchedule(Long userId, Long scheduleId)
    {
        requireTalent(userId);
        Map<String, Object> schedule = candidateExamMapper.selectScheduleForCandidate(userId, scheduleId);
        if (schedule == null)
        {
            throw new ServiceException("考试安排不存在或无权访问");
        }
        return schedule;
    }

    /** 记录归属校验 + 必须处于进行中 */
    private Map<String, Object> requireActiveRecord(Long userId, Long recordId)
    {
        Map<String, Object> record = candidateExamMapper.selectRecordForCandidate(userId, recordId);
        if (record == null)
        {
            throw new ServiceException("考试记录不存在或无权访问");
        }
        int status = asInt(record.get("status"), 0);
        if (status == 2 || status == 4)
        {
            throw new ServiceException("已交卷，不能继续作答");
        }
        if (status == 3)
        {
            throw new ServiceException("本次考试已作废（超时未交卷）");
        }
        return record;
    }

    /** 旧版种子规则键名 → 题型 */
    private static final Map<String, Integer> LEGACY_TYPE_KEYS = legacyTypeKeys();

    private static Map<String, Integer> legacyTypeKeys()
    {
        Map<String, Integer> map = new LinkedHashMap<>();
        map.put("single", 1);
        map.put("multiple", 2);
        map.put("judge", 3);
        map.put("short", 4);
        map.put("coding", 5);
        return map;
    }

    /** 开考快照：随机卷按规则抽题，人工卷按试卷选题 */
    private void snapshotQuestions(Long paperId, Object rule, Long recordId)
    {
        Long companyId = examMapper.selectRecordCompanyId(recordId);
        List<Map<String, Object>> picked = new ArrayList<>();
        if (rule instanceof Map && !((Map<?, ?>) rule).containsKey("rules"))
        {
            for (Map.Entry<String, Integer> entry : LEGACY_TYPE_KEYS.entrySet())
            {
                picked.addAll(drawByGroup(entry.getValue(), null, null,
                        asInt(((Map<?, ?>) rule).get(entry.getKey()), 0), null, companyId));
            }
        }
        else if (rule != null)
        {
            for (Map<String, Object> item : ruleList(rule))
            {
                picked.addAll(drawByGroup(asInt(item.get("type"), null), asInt(item.get("difficulty"), null),
                        asString(item.get("skillTag")), asInt(item.get("count"), 0), asDecimal(item.get("score")),
                        companyId));
            }
        }
        else
        {
            picked.addAll(examMapper.selectPaperQuestions(paperId));
        }
        for (Map<String, Object> q : picked)
        {
            candidateExamMapper.insertAnswerSnapshot(recordId, asLong(q.get("questionId")),
                    asDecimal(q.get("score")));
        }
    }

    /** 按规则分组抽题；score 为空时沿用题目自身分值 */
    private List<Map<String, Object>> drawByGroup(Integer type, Integer difficulty, String skillTag,
            int count, BigDecimal score, Long companyId)
    {
        List<Map<String, Object>> result = new ArrayList<>();
        if (count <= 0)
        {
            return result;
        }
        List<Map<String, Object>> drawn = examMapper.drawQuestions(type, difficulty, skillTag, null, count,
                companyId);
        if (drawn.size() < count)
        {
            throw new ServiceException("题库题目不足，请联系招聘方");
        }
        for (Map<String, Object> q : drawn)
        {
            if (score != null)
            {
                q.put("score", score);
            }
            result.add(q);
        }
        return result;
    }

    /** 进行中记录的返回体：题目快照（不含答案）+ 剩余时间 */
    private Map<String, Object> resumeResult(Map<String, Object> record, LocalDateTime deadline,
            LocalDateTime now)
    {
        List<Map<String, Object>> questions = candidateExamMapper
                .selectRecordQuestions(asLong(record.get("recordId")));
        for (Map<String, Object> q : questions)
        {
            q.put("options", parseJson(q.get("optionsJson")));
            q.remove("optionsJson");
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordId", record.get("recordId"));
        result.put("status", 1);
        result.put("paperName", record.get("paperName"));
        result.put("positionTitle", record.get("positionTitle"));
        result.put("totalScore", record.get("totalScore"));
        result.put("durationMin", record.get("durationMin"));
        result.put("startAt", record.get("startAt"));
        result.put("deadline", deadline == null ? null : deadline.format(TIME_FORMAT));
        result.put("remainingSec", remaining(deadline, now));
        result.put("questionCount", questions.size());
        result.put("questions", questions);
        return result;
    }

    private Map<String, Object> submittedResult(Map<String, Object> record, boolean auto)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordId", record.get("recordId"));
        result.put("status", record.get("status"));
        result.put("submitted", true);
        result.put("auto", auto);
        result.put("submitAt", record.get("submitAt"));
        result.put("paperName", record.get("paperName"));
        result.put("positionTitle", record.get("positionTitle"));
        result.put("earnedScore", record.get("earnedScore"));
        result.put("passStatus", record.get("passStatus"));
        return result;
    }

    /** 定时结算：已开始未交卷的自动交卷，未开考且安排结束的按缺考收口 */
    @Override
    public int settleExpiredRecords()
    {
        int settled = 0;
        LocalDateTime now = LocalDateTime.now();
        for (Map<String, Object> row : candidateExamMapper.selectExpiredInProgressRecords())
        {
            LocalDateTime deadline = deadline(asTime(row.get("startAt")),
                    asInt(row.get("durationMin"), 0), asTime(row.get("endAt")));
            if (deadline == null || now.isBefore(deadline))
            {
                continue;
            }
            // 已开考未交卷：自动交卷，保留最后一次作答，等待笔试成绩；节点已在开考时 start，终判时 complete
            Long talId = asLong(row.get("talId"));
            Long positionId = asLong(row.get("positionId"));
            talStatusService.change(talId, TalStatusService.TAL_EXAM_TAKING,
                    List.of(0, 1, 2, 5, 6, 7, 8, 9), positionId, null, "笔试到期自动交卷", 0L);
            candidateExamMapper.updateRecordSubmitted(asLong(row.get("recordId")));
            tryGrade(asLong(row.get("recordId")));
            settled++;
        }
        for (Map<String, Object> row : candidateExamMapper.selectExpiredUnstartedRecords())
        {
            Long recordId = asLong(row.get("recordId"));
            if (candidateExamMapper.updateRecordAbandoned(recordId) != 1)
            {
                continue;
            }
            // 未开考且安排已结束：认定为笔试缺考；只写节点结果，不终止投递（HR 可补考/新一轮）
            talStatusService.change(asLong(row.get("talId")), TalStatusService.TAL_EXAM_ABSENT,
                    List.of(5), asLong(row.get("positionId")), null, "笔试缺考", 0L);
            completeExamNode(recordId, asLong(row.get("talId")), asLong(row.get("positionId")),
                    ProcessStageInstance.RESULT_ABSENT, "笔试缺考", 0L);
            settled++;
        }
        return settled;
    }

    /** 开考：按 refId=recordId 幂等建立本轮笔试节点并 start；无流程实例则跳过（不阻断考试） */
    private void openExamNode(Long recordId, Long talId, Long positionId, Long operatorId)
    {
        Long instanceId = resolveInstanceId(talId, positionId);
        if (instanceId == null || recordId == null)
        {
            return;
        }
        try
        {
            ProcessStageInstance node = processStageInstanceService.getOrCreate(instanceId, null,
                    ProcessStageInstance.TYPE_EXAM, "在线笔试", recordId, operatorId);
            if (node != null && node.getId() != null)
            {
                processStageInstanceService.start(node.getId(), operatorId);
            }
        }
        catch (Exception ignore)
        {
            // 节点写入失败不阻断考试主流程
        }
    }

    /** 收口本轮笔试节点（通过/未通过/缺考）：按 refId=recordId 幂等 complete */
    private void completeExamNode(Long recordId, Long talId, Long positionId, int result,
            String note, Long operatorId)
    {
        Long instanceId = resolveInstanceId(talId, positionId);
        if (instanceId == null || recordId == null)
        {
            return;
        }
        try
        {
            ProcessStageInstance node = processStageInstanceService.getOrCreate(instanceId, null,
                    ProcessStageInstance.TYPE_EXAM, "在线笔试", recordId, operatorId);
            if (node != null && node.getId() != null)
            {
                processStageInstanceService.complete(node.getId(), result, note);
            }
        }
        catch (Exception ignore)
        {
            // 节点收口失败不影响笔试成绩
        }
    }

    /** 由候选人+岗位解析投递的流程实例ID；不存在或异常返回 null */
    private Long resolveInstanceId(Long talId, Long positionId)
    {
        if (talId == null || positionId == null)
        {
            return null;
        }
        try
        {
            Long appId = applicationStatusMapper.selectAppId(talId, positionId);
            if (appId == null)
            {
                return null;
            }
            Map<String, Object> app = applicationStatusMapper.selectApplicationById(appId);
            return app == null ? null : asLong(app.get("instanceId"));
        }
        catch (Exception ignore)
        {
            return null;
        }
    }

    /** 强制双机位：副机位未在线禁止开考或续考 */
    private void requireDualCameraReady(Long recordId)
    {
        if (!examMonitorService.isDualCameraReady(recordId))
        {
            throw new ServiceException("本场考试要求双机位监考，请先在设备检测页完成副机位扫码并保持连接");
        }
    }

    /** 超时处理：autoSubmit=true（默认）自动交卷，否则记录作废 */
    private Map<String, Object> expireRecord(Long userId, Map<String, Object> record)
    {
        Long recordId = asLong(record.get("recordId"));
        Object ruleRaw = parseJson(record.get("submitRule"));
        boolean autoSubmit = true;
        if (ruleRaw instanceof Map)
        {
            // 兼容两种键名：autoSubmit（企业端配置页）与 autoSubmitOnTimeout（历史种子数据）
            Map<?, ?> ruleMap = (Map<?, ?>) ruleRaw;
            Object flag = ruleMap.get("autoSubmit") != null ? ruleMap.get("autoSubmit")
                    : ruleMap.get("autoSubmitOnTimeout");
            autoSubmit = flag == null || Boolean.parseBoolean(String.valueOf(flag));
        }
        if (autoSubmit)
        {
            candidateExamMapper.updateRecordSubmitted(recordId);
            tryGrade(recordId);
            Map<String, Object> graded = candidateExamMapper
                    .selectRecordForCandidate(userId, recordId);
            if (graded != null)
            {
                return submittedResult(graded, true);
            }
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("recordId", recordId);
            result.put("status", 2);
            result.put("submitted", true);
            result.put("auto", true);
            result.put("submitAt", LocalDateTime.now().format(TIME_FORMAT));
            result.put("paperName", record.get("paperName"));
            result.put("positionTitle", record.get("positionTitle"));
            return result;
        }
        candidateExamMapper.updateRecordAbandoned(recordId);
        // 超时未交卷且未自动交卷：候选人记为笔试缺考；节点写缺考结果，不终止投递
        talStatusService.change(asLong(record.get("talId")), TalStatusService.TAL_EXAM_ABSENT,
                List.of(5, 6), asLong(record.get("positionId")), null, "笔试超时未交卷", userId);
        completeExamNode(recordId, asLong(record.get("talId")), asLong(record.get("positionId")),
                ProcessStageInstance.RESULT_ABSENT, "笔试超时未交卷", userId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordId", recordId);
        result.put("status", 3);
        result.put("abandoned", true);
        return result;
    }

    private LocalDateTime deadline(LocalDateTime startAt, int durationMin, LocalDateTime endAt)
    {
        if (startAt == null)
        {
            return endAt;
        }
        LocalDateTime byDuration = startAt.plusMinutes(durationMin);
        if (endAt == null)
        {
            return byDuration;
        }
        return byDuration.isBefore(endAt) ? byDuration : endAt;
    }

    private long remaining(LocalDateTime deadline, LocalDateTime now)
    {
        if (deadline == null)
        {
            return 0;
        }
        long sec = Duration.between(now, deadline).getSeconds();
        return Math.max(sec, 0);
    }

    private boolean isOpenNow(LocalDateTime startAt, LocalDateTime endAt)
    {
        LocalDateTime now = LocalDateTime.now();
        return startAt != null && endAt != null && !now.isBefore(startAt) && !now.isAfter(endAt);
    }

    // ==================== 工具 ====================

    private LocalDateTime asTime(Object value)
    {
        String s = asString(value);
        if (s == null)
        {
            return null;
        }
        try
        {
            if (s.length() == 16)
            {
                s = s + ":00";
            }
            return LocalDateTime.parse(s, TIME_FORMAT);
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

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> ruleList(Object rule)
    {
        Object raw = rule instanceof Map ? ((Map<String, Object>) rule).get("rules") : null;
        List<Map<String, Object>> result = new ArrayList<>();
        if (raw instanceof List)
        {
            for (Object item : (List<Object>) raw)
            {
                if (item instanceof Map)
                {
                    result.add((Map<String, Object>) item);
                }
            }
        }
        return result;
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
}
