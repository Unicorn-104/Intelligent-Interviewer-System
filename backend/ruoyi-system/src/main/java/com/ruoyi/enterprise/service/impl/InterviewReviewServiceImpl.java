package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.enterprise.service.TalStatusService;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.enums.ApplicationEndReason;
import com.ruoyi.common.enums.ApplicationStatus;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.domain.ProcessStageInstance;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.mapper.InterviewReviewMapper;
import com.ruoyi.enterprise.service.ApplicationStatusService;
import com.ruoyi.enterprise.service.IInterviewReviewService;
import com.ruoyi.enterprise.service.ProcessStageInstanceService;
import com.ruoyi.system.event.InterviewFinishedEvent;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.InterviewReportMapper;

/**
 * 企业端 - HR 终审与级联流转服务实现
 *
 * <p>依据《业务功能分析》：</p>
 * <ul>
 *   <li>UC-12 步骤8：确认通过 / 调整后通过（修改五维评分重算综合分）/ 驳回淘汰</li>
 *   <li>UC-12 步骤9：终面通过 → 触发 Offer 流程（由 OfferController 提供触发入口）</li>
 *   <li>UC-15：非终面通过 → 按级联规则（t_int_cascade_rule）评分阈值判断，
 *       达标自动创建下一轮预约任务，未达标直接淘汰（UC-12 E2）</li>
 *   <li>UC-12 步骤10：驳回 → 候选人状态"已淘汰"（tal_status=3，数据库触发器写状态日志）
 *       + 发送"感谢参与"消息</li>
 * </ul>
 *
 * @author enterprise
 */
@Service
public class InterviewReviewServiceImpl implements IInterviewReviewService
{
    /** HR 审核状态（DB 设计文档 §4.3）：0-未审核，1-已确认，2-已修改 */
    private static final int HR_PENDING = 0;
    private static final int HR_CONFIRMED = 1;
    private static final int HR_ADJUSTED = 2;

    /** 候选人状态（DB 设计文档 §3.3）：3-已淘汰 */
    private static final int TAL_REJECTED = 3;

    private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Autowired
    private InterviewReviewMapper reviewMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Autowired
    private TalStatusService talStatusService;

    @Autowired
    private InterviewReportMapper reportMapper;

    @Autowired
    private ApplicationStatusService applicationStatusService;

    @Autowired
    private ApplicationStatusMapper applicationStatusMapper;

    @Autowired
    private ProcessStageInstanceService stageInstanceService;

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    @Override
    public List<Map<String, Object>> listReviews(Long userId, Integer status, Integer pageNum, Integer pageSize)
    {
        Long companyId = resolveCompanyId(userId);
        PageUtils.startPage(pageNum, pageSize);
        return reviewMapper.selectReviewList(companyId, status);
    }

    @Override
    public Map<String, Object> getReviewDetail(Long userId, Long sessionId)
    {
        Map<String, Object> detail = reviewMapper.selectReviewDetail(sessionId);
        if (detail == null || !resolveCompanyId(userId).equals(asLong(detail.get("companyId"))))
        {
            throw new ServiceException("面试记录或评估结果不存在");
        }
        Map<String, Object> result = new LinkedHashMap<>(detail);
        result.put("dimensionScores", detail.get("dimensionScores") == null ? null
                : JSON.parse(String.valueOf(detail.get("dimensionScores"))));
        result.put("aiSnapshot", detail.get("aiSnapshot") == null ? null
                : JSON.parse(String.valueOf(detail.get("aiSnapshot"))));
        return result;
    }

    @Override
    public Map<String, Object> retryReport(Long userId, Long sessionId)
    {
        Map<String, Object> session = requireSession(userId, sessionId);
        int reportStatus = session.get("reportStatus") == null ? 0
                : Integer.parseInt(String.valueOf(session.get("reportStatus")));
        if (session.get("overallScore") != null || reportStatus == 2)
        {
            throw new ServiceException("报告已生成，无需重新生成");
        }
        if (reportStatus == 1)
        {
            throw new ServiceException("报告正在生成，请稍后刷新");
        }
        // 手动重试重新计数，避免历史失败次数耗尽自动补偿配额
        reportMapper.resetReportRetry(sessionId);
        eventPublisher.publishEvent(new InterviewFinishedEvent(sessionId));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("reportStatus", "generating");
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> confirm(Long userId, Long sessionId, Boolean isFinal,
            Integer recommendation, String comment)
    {
        Map<String, Object> session = requireSession(userId, sessionId);
        // UC-12 步骤8：确认通过（HR 结论与评语随确认一同落库）
        reviewMapper.updateHrStatus(sessionId, HR_CONFIRMED,
                recommendation == null ? 1 : recommendation, comment);
        // 本轮面试节点按 HR 结论记结果（节点结果不等同投递结果，幂等）
        completeInterviewNode(session,
                (recommendation != null && recommendation == 0) ? ProcessStageInstance.RESULT_FAIL
                        : ProcessStageInstance.RESULT_PASS,
                comment);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("hrStatus", HR_CONFIRMED);
        if (Boolean.FALSE.equals(isFinal))
        {
            // UC-15：非终面通过 → 自动触发下一轮预约（级联）
            result.put("cascade", cascadeInternal(session));
            result.put("message", "已确认通过（非终面），已自动创建下一轮预约任务（级联流转 UC-15）");
        }
        else
        {
            // 终面通过 → 候选人进入「待发 Offer」，后续由 Offer 接受/拒绝收口到录用/淘汰
            advanceToPendingOffer(session, userId, "终面通过");
            result.put("message", "已确认通过（终面），候选人状态已更新为待发 Offer，请前往 Offer 管理触发录用意向书发送");
        }
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> adjust(Long userId, Long sessionId, Map<String, Object> dims,
            Integer recommendation, String comment, Boolean isFinal)
    {
        Map<String, Object> session = requireSession(userId, sessionId);
        if (dims == null || dims.isEmpty())
        {
            throw new ServiceException("调整的五维评分不能为空");
        }
        // UC-12 步骤8：调整后通过——重算综合分（五维平均，维度权重以评分卡配置为准）
        double total = 0;
        for (Object value : dims.values())
        {
            total += Double.parseDouble(String.valueOf(value));
        }
        double overall = round(total / dims.size());
        // 首次调整前留存 AI 原始评分，便于终审页对比，重复调整不覆盖首次快照
        reviewMapper.snapshotAiEvaluation(sessionId);
        reviewMapper.updateDimensionScores(sessionId, JSON.toJSONString(dims), overall);
        reviewMapper.updateHrStatus(sessionId, HR_ADJUSTED,
                recommendation == null ? 1 : recommendation,
                comment == null || comment.isBlank() ? "调整后通过" : comment);
        completeInterviewNode(session,
                (recommendation != null && recommendation == 0) ? ProcessStageInstance.RESULT_FAIL
                        : ProcessStageInstance.RESULT_PASS,
                comment);
        if (Boolean.TRUE.equals(isFinal))
        {
            // 终面调整后通过同样进入「待发 Offer」；非终面的级联由调用方单独触发
            advanceToPendingOffer(session, userId, "终面调整后通过");
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("overallScore", overall);
        result.put("hrStatus", HR_ADJUSTED);
        result.put("message", "评分已调整并确认通过");
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> reject(Long userId, Long sessionId, String reason)
    {
        Map<String, Object> session = requireSession(userId, sessionId);
        // UC-12 步骤10：驳回淘汰——候选人状态"已淘汰"，归档来源记为面试淘汰(2)，状态日志由状态机统一写入
        reviewMapper.updateHrStatus(sessionId, HR_CONFIRMED, 0, reason);
        if (!talStatusService.change(asLong(session.get("candidateId")), TalStatusService.TAL_REJECTED, List.of(2),
                asLong(session.get("positionId")), 2, "面试未通过", userId))
            throw new ServiceException("候选人已淘汰或已录用，无法重复驳回");
        // 本轮面试节点记未通过；HR 主动淘汰经状态机进入未录用（HR_REJECTED，必须记录操作人）
        completeInterviewNode(session, ProcessStageInstance.RESULT_FAIL, reason);
        Long appId = applicationStatusMapper.selectAppId(asLong(session.get("candidateId")),
                asLong(session.get("positionId")));
        if (appId != null)
        {
            applicationStatusService.terminate(appId, ApplicationEndReason.HR_REJECTED, userId,
                    ApplicationStatusService.SOURCE_INTERVIEW, "面试未通过：" + reason);
        }
        reviewMapper.insertMessage(Long.valueOf(String.valueOf(session.get("candidateUserId"))),
                "感谢参与",
                "感谢您参与「" + session.get("positionTitle") + "」的面试。很遗憾本次未能与您携手，"
                        + "您的简历已归档至人才库，期待未来有合适机会再与您联系。");
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("message", "已驳回：候选人状态已更新为已淘汰，简历已归档人才库，感谢信已发送");
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> cascade(Long userId, Long sessionId)
    {
        return cascadeInternal(requireSession(userId, sessionId));
    }

    /** UC-15 级联流转核心：按级联规则阈值判断，达标创建下一轮预约，未达标淘汰 */
    private Map<String, Object> cascadeInternal(Map<String, Object> session)
    {
        Long sessionId = Long.valueOf(String.valueOf(session.get("sessionId")));
        Object templateObj = session.get("templateId");
        Integer currentRound = session.get("round") == null ? 1
                : Integer.valueOf(String.valueOf(session.get("round")));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        if (templateObj == null)
        {
            result.put("message", "该面试未配置流程模板，无法级联");
            return result;
        }
        Long templateId = Long.valueOf(String.valueOf(templateObj));
        Integer nextRound = currentRound + 1;
        Map<String, Object> rule = reviewMapper.selectCascadeRule(templateId, nextRound);
        if (rule == null)
        {
            result.put("message", "未配置第 " + nextRound + " 轮级联规则");
            return result;
        }
        double overall = session.get("overallScore") == null ? 0
                : Double.parseDouble(String.valueOf(session.get("overallScore")));
        double threshold = Double.parseDouble(String.valueOf(rule.get("passThreshold")));
        if (overall < threshold)
        {
            // UC-12 E2：级联模式评分未达阈值，直接走淘汰流程；候选人已处于终态时不再改写
            if (!talStatusService.change(asLong(session.get("candidateId")), TalStatusService.TAL_REJECTED,
                    List.of(2), asLong(session.get("positionId")), 2, "面试级联未达标", 0L))
            {
                result.put("message", "候选人已淘汰或已录用，本次不再重复流转状态");
                return result;
            }
            reviewMapper.insertMessage(Long.valueOf(String.valueOf(session.get("candidateUserId"))),
                    "感谢参与",
                    "感谢您参与「" + session.get("positionTitle") + "」的面试。很遗憾本次未能与您携手，期待未来再会。");
            result.put("message", "综合评分 " + overall + " 低于级联阈值 " + threshold + "，已按淘汰流程处理（UC-12 E2）");
            return result;
        }
        // 达标：创建下一轮预约任务（建议时间为当前时间 +3 天，P7 与调度引擎对齐后由模块三排期）
        LocalDateTime nextStart = LocalDateTime.now().plusDays(3).withMinute(0).withSecond(0);
        LocalDateTime nextEnd = nextStart.plusMinutes(45);
        reviewMapper.insertCascadeAppointment(
                Long.valueOf(String.valueOf(session.get("candidateId"))),
                Long.valueOf(String.valueOf(session.get("positionId"))),
                Long.valueOf(String.valueOf(session.get("interviewerId"))),
                nextStart.format(TIME_FORMAT), nextEnd.format(TIME_FORMAT));
        reviewMapper.insertMessage(Long.valueOf(String.valueOf(session.get("candidateUserId"))),
                "下一轮面试邀请",
                "恭喜您通过本轮面试，我们已为您自动创建下一轮（第 " + nextRound + " 轮）面试预约任务，"
                        + "排期确认后将以专属链接通知您。");
        result.put("nextRound", nextRound);
        result.put("suggestedTime", nextStart.format(TIME_FORMAT));
        result.put("message", "已自动创建第 " + nextRound + " 轮面试预约任务，并通知候选人");
        return result;
    }

    /** 终面通过：候选人从面试中进入「待发 Offer」，已淘汰/已录用等终态不再流转 */
    private void advanceToPendingOffer(Map<String, Object> session, Long userId, String reason)
    {
        if (!talStatusService.change(asLong(session.get("candidateId")), TalStatusService.TAL_PENDING_OFFER,
                List.of(TalStatusService.TAL_INTERVIEWING, TalStatusService.TAL_PENDING_OFFER),
                asLong(session.get("positionId")), null, reason, userId))
        {
            throw new ServiceException("候选人已淘汰或已录用，无法进入待发 Offer");
        }
        // 岗位投递经状态机：招聘中(1)→待发Offer(2)；尚未启动时先补启动，终态由状态机拦截
        Long appId = applicationStatusMapper.selectAppId(asLong(session.get("candidateId")),
                asLong(session.get("positionId")));
        if (appId != null)
        {
            Map<String, Object> app = applicationStatusMapper.selectApplicationById(appId);
            Integer cur = app == null ? null : toStatusInt(app.get("status"));
            if (ApplicationStatus.fromCode(cur) == ApplicationStatus.APPLIED)
            {
                applicationStatusService.startRecruitment(appId, userId);
            }
            applicationStatusService.passToPendingOffer(appId, userId);
        }
    }

    /** 按面试预约(apt_id)幂等定位并完成本轮面试节点；节点结果不等同投递结果。 */
    private void completeInterviewNode(Map<String, Object> session, int result, String note)
    {
        Long appointmentId = asLong(session.get("appointmentId"));
        if (appointmentId == null) return;
        Long appId = applicationStatusMapper.selectAppId(asLong(session.get("candidateId")),
                asLong(session.get("positionId")));
        if (appId == null) return;
        Map<String, Object> app = applicationStatusMapper.selectApplicationById(appId);
        Object inst = app == null ? null : app.get("instanceId");
        if (inst == null) return;
        ProcessStageInstance node = stageInstanceService.getOrCreate(Long.valueOf(String.valueOf(inst)),
                null, ProcessStageInstance.TYPE_HR_INTERVIEW, "HR综合面试", appointmentId, null);
        stageInstanceService.complete(node.getId(), result, note);
    }

    private Integer toStatusInt(Object value)
    {
        if (value == null) return null;
        try { return Integer.parseInt(String.valueOf(value)); }
        catch (Exception e) { return null; }
    }

    private Map<String, Object> requireSession(Long userId, Long sessionId)
    {
        Map<String, Object> session = reviewMapper.selectSessionBase(sessionId);
        if (session == null || !resolveCompanyId(userId).equals(asLong(session.get("companyId"))))
        {
            throw new ServiceException("面试记录不存在");
        }
        return session;
    }

    private Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }

    private Long asLong(Object value)
    {
        return value == null ? null : Long.valueOf(String.valueOf(value));
    }

    private double round(double value)
    {
        return BigDecimal.valueOf(value).setScale(1, RoundingMode.HALF_UP).doubleValue();
    }
}
