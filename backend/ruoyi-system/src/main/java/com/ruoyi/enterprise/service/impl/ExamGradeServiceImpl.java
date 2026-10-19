package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.mapper.ExamGradeMapper;
import com.ruoyi.enterprise.service.IExamGradeService;
import com.ruoyi.enterprise.service.IInterviewScheduleService;
import com.ruoyi.system.mapper.DashboardMapper;

/**
 * 企业端 - 笔试判分与成绩报告服务实现
 *
 * <p>判分口径：单选按字母比对；多选按去重排序后的字母集合比对；判断题兼容
 * "对/错"与"A/B"两种取值（A→对、B→错）；未作答判 0 分。客观题得分回填
 * t_exam_answer（ean_is_correct/ean_score），汇总写 t_exam_result 与
 * t_exam_record（erc_total_score/erc_pass_status）。</p>
 * <p>流转：全部为客观题时交卷即终判（erc_status=4）；含主观题时先置
 * "待主观题评分"（erc_pass_status=2），人工录入主观分后终判。通过→
 * t_tal.tal_status=7 并按 esd_auto_flow_json 配置调用面试邀约 Service
 * 自动创建预约（未配置或时段冲突则提示人工安排）；未通过→tal_status=8
 * 归档人才库（状态日志由数据库触发器写入）。</p>
 *
 * @author enterprise
 */
@Service
public class ExamGradeServiceImpl implements IExamGradeService
{
    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    /** 人才库状态：7-笔试通过，8-笔试未通过 */
    private static final int TAL_EXAM_PASSED = 7;
    private static final int TAL_EXAM_FAILED = 8;

    @Autowired
    private ExamGradeMapper gradeMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Autowired
    private IInterviewScheduleService scheduleService;

    // ==================== 交卷自动判分 ====================

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> gradeOnSubmit(Long recordId)
    {
        Map<String, Object> ctx = gradeMapper.selectRecordForGrade(recordId);
        if (ctx == null)
        {
            throw new ServiceException("考试记录不存在");
        }
        if (asInt(ctx.get("status"), 0) != 2)
        {
            throw new ServiceException("记录未处于已交卷状态，无法判分");
        }
        Long operatorUserId = asLong(ctx.get("candidateUserId"));
        return gradeRecord(ctx, operatorUserId == null ? 0L : operatorUserId, null, false);
    }

    // ==================== 主观题人工评分 ====================

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> gradeSubjective(Long userId, Long recordId,
            List<Map<String, Object>> scores, String comment)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> ctx = gradeMapper.selectRecordForCompany(recordId, companyId);
        if (ctx == null)
        {
            throw new ServiceException("考试记录不存在或无权访问");
        }
        if (asInt(ctx.get("passStatus"), -1) != 2)
        {
            throw new ServiceException("该记录不处于待主观题评分状态");
        }
        Map<Long, BigDecimal> given = new LinkedHashMap<>();
        if (scores != null)
        {
            for (Map<String, Object> item : scores)
            {
                Long questionId = asLong(item.get("questionId"));
                BigDecimal score = asDecimal(item.get("score"));
                if (questionId != null)
                {
                    given.put(questionId, score == null ? BigDecimal.ZERO : score);
                }
            }
        }
        List<Map<String, Object>> answers = gradeMapper.selectGradingAnswers(recordId);
        boolean hasSubjective = false;
        for (Map<String, Object> answer : answers)
        {
            if (asInt(answer.get("type"), 0) <= 3)
            {
                continue;
            }
            hasSubjective = true;
            BigDecimal max = asDecimal(answer.get("maxScore"));
            BigDecimal score = given.get(asLong(answer.get("questionId")));
            if (score == null)
            {
                score = BigDecimal.ZERO;
            }
            if (score.compareTo(BigDecimal.ZERO) < 0)
            {
                score = BigDecimal.ZERO;
            }
            if (max != null && score.compareTo(max) > 0)
            {
                score = max;
            }
            gradeMapper.updateAnswerScore(asLong(answer.get("eanId")), score.setScale(2, RoundingMode.HALF_UP));
        }
        if (!hasSubjective)
        {
            throw new ServiceException("该试卷不含主观题，无需人工评分");
        }
        return gradeRecord(ctx, userId, comment, true);
    }

    // ==================== 成绩报告 ====================

    @Override
    public List<Map<String, Object>> listResults(Long userId, Long positionId,
            Integer passStatus, Integer pageNum, Integer pageSize)
    {
        Long companyId = resolveCompanyId(userId);
        PageUtils.startPage(pageNum, pageSize);
        return gradeMapper.selectResultList(companyId, positionId, passStatus);
    }

    @Override
    public Map<String, Object> getResult(Long userId, Long recordId)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> ctx = gradeMapper.selectRecordForCompany(recordId, companyId);
        if (ctx == null)
        {
            throw new ServiceException("考试记录不存在或无权访问");
        }
        List<Map<String, Object>> answers = gradeMapper.selectResultAnswers(recordId);
        for (Map<String, Object> answer : answers)
        {
            answer.put("options", parseJson(answer.get("optionsJson")));
            answer.remove("optionsJson");
        }
        Map<String, Object> result = new LinkedHashMap<>(ctx);
        result.put("answers", answers);
        return result;
    }

    // ==================== 判分核心 ====================

    /**
     * 重算并落库：客观题逐题判分回填，主观题取已录得分。
     *
     * @param finalize false=交卷触发（含主观题时仅置待评分），true=主观分录入后终判
     */
    private Map<String, Object> gradeRecord(Map<String, Object> ctx, Long operatorUserId,
            String commentOverride, boolean finalize)
    {
        Long recordId = asLong(ctx.get("recordId"));
        List<Map<String, Object>> answers = gradeMapper.selectGradingAnswers(recordId);
        BigDecimal objective = BigDecimal.ZERO;
        BigDecimal subjective = BigDecimal.ZERO;
        int subjectiveCount = 0;
        for (Map<String, Object> answer : answers)
        {
            int type = asInt(answer.get("type"), 0);
            BigDecimal max = asDecimal(answer.get("maxScore"));
            if (max == null)
            {
                max = BigDecimal.ZERO;
            }
            if (type <= 3)
            {
                boolean correct = matches(type, asString(answer.get("content")),
                        asString(answer.get("stdAnswer")));
                BigDecimal score = correct ? max : BigDecimal.ZERO;
                gradeMapper.updateAnswerGrade(asLong(answer.get("eanId")), correct ? 1 : 0,
                        score.setScale(2, RoundingMode.HALF_UP));
                objective = objective.add(score);
            }
            else
            {
                subjectiveCount++;
                BigDecimal score = asDecimal(answer.get("score"));
                if (score != null)
                {
                    subjective = subjective.add(score);
                }
            }
        }
        BigDecimal total = objective.add(subjective).setScale(2, RoundingMode.HALF_UP);
        BigDecimal threshold = asDecimal(ctx.get("passThreshold"));
        int passStatus;
        int recordStatus;
        if (subjectiveCount > 0 && !finalize)
        {
            passStatus = 2;
            recordStatus = 2;
        }
        else
        {
            boolean pass = threshold == null || total.compareTo(threshold) >= 0;
            passStatus = pass ? 1 : 0;
            recordStatus = 4;
        }
        gradeMapper.updateRecordScored(recordId, total, passStatus, recordStatus);

        String comment = buildComment(ctx, commentOverride, objective, subjective,
                total, threshold, passStatus, operatorUserId);
        Map<String, Object> params = new LinkedHashMap<>();
        params.put("recordId", recordId);
        params.put("objectiveScore", objective.setScale(2, RoundingMode.HALF_UP));
        params.put("subjectiveScore", subjective.setScale(2, RoundingMode.HALF_UP));
        params.put("totalScore", total);
        params.put("passStatus", passStatus);
        params.put("comment", comment);
        gradeMapper.upsertResult(params);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordId", recordId);
        result.put("objectiveScore", params.get("objectiveScore"));
        result.put("subjectiveScore", params.get("subjectiveScore"));
        result.put("totalScore", total);
        result.put("passThreshold", threshold);
        result.put("passStatus", passStatus);
        result.put("status", recordStatus);
        result.put("comment", comment);
        return result;
    }

    /** 终判时执行人才库流转并组装报告评语 */
    private String buildComment(Map<String, Object> ctx, String commentOverride,
            BigDecimal objective, BigDecimal subjective, BigDecimal total,
            BigDecimal threshold, int passStatus, Long operatorUserId)
    {
        StringBuilder sb = new StringBuilder();
        if (StringUtils.isNotEmpty(commentOverride))
        {
            sb.append(commentOverride.trim()).append("；");
        }
        if (passStatus == 2)
        {
            sb.append("客观题得分 ").append(objective.stripTrailingZeros().toPlainString())
              .append("，待主观题评分");
            return sb.toString();
        }
        Long talId = asLong(ctx.get("talId"));
        if (passStatus == 1)
        {
            gradeMapper.updateTalStatus(talId, TAL_EXAM_PASSED, asLong(ctx.get("recordId")));
            sb.append("总分 ").append(total.stripTrailingZeros().toPlainString())
              .append(" ≥ 阈值 ").append(threshold == null ? "-" : threshold.stripTrailingZeros().toPlainString())
              .append("，笔试通过；");
            sb.append(autoInvite(ctx, operatorUserId));
        }
        else
        {
            gradeMapper.updateTalStatus(talId, TAL_EXAM_FAILED, asLong(ctx.get("recordId")));
            sb.append("总分 ").append(total.stripTrailingZeros().toPlainString())
              .append(" < 阈值 ").append(threshold == null ? "-" : threshold.stripTrailingZeros().toPlainString())
              .append("，未通过，已归档人才库");
        }
        return sb.toString();
    }

    /** 通过自动邀约：读取考试安排 esd_auto_flow_json，复用面试邀约 Service */
    private String autoInvite(Map<String, Object> ctx, Long operatorUserId)
    {
        Object raw = parseJson(ctx.get("autoFlow"));
        Long interviewerId = raw instanceof Map ? asLong(((Map<?, ?>) raw).get("interviewerId")) : null;
        if (interviewerId == null)
        {
            return "请在面试安排中心手动邀约面试";
        }
        int days = raw instanceof Map ? asInt(((Map<?, ?>) raw).get("startAfterDays"), 3) : 3;
        int duration = raw instanceof Map ? asInt(((Map<?, ?>) raw).get("durationMin"), 45) : 45;
        LocalDateTime start = LocalDateTime.now().plusDays(Math.max(days, 0))
                .withMinute(0).withSecond(0).withNano(0);
        try
        {
            Map<String, Object> invite = scheduleService.invite(operatorUserId,
                    asLong(ctx.get("talId")), asLong(ctx.get("positionId")), interviewerId,
                    start.format(TIME_FORMAT), duration);
            return "已自动创建面试邀约 #" + invite.get("appointmentId")
                    + "（建议时间 " + invite.get("startTime") + "）";
        }
        catch (ServiceException e)
        {
            return "自动邀约失败：" + e.getMessage() + "，请手动安排";
        }
    }

    // ==================== 客观题比对 ====================

    private boolean matches(int type, String content, String std)
    {
        String c = normalize(content);
        String s = normalize(std);
        if (c.isEmpty() || s.isEmpty())
        {
            return false;
        }
        if (type == 2)
        {
            c = sortLetters(c);
            s = sortLetters(s);
        }
        else if (type == 3)
        {
            c = mapJudge(c);
            s = mapJudge(s);
        }
        return c.equals(s);
    }

    private String normalize(String value)
    {
        return value == null ? "" : value.trim().toUpperCase();
    }

    /** 多选：去重并排序字母，"ba" 与 "AB" 等价 */
    private String sortLetters(String value)
    {
        TreeSet<Character> set = new TreeSet<>();
        for (char ch : value.toCharArray())
        {
            if (ch != ',')
            {
                set.add(ch);
            }
        }
        StringBuilder sb = new StringBuilder();
        for (Character ch : set)
        {
            sb.append(ch);
        }
        return sb.toString();
    }

    /** 判断：A→对、B→错，其余原样 */
    private String mapJudge(String value)
    {
        if ("A".equals(value))
        {
            return "对";
        }
        if ("B".equals(value))
        {
            return "错";
        }
        return value;
    }

    // ==================== 工具 ====================

    private Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
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

    private int asInt(Object v, int defaultValue)
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
        return s.isEmpty() ? defaultValue : Integer.parseInt(s);
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
