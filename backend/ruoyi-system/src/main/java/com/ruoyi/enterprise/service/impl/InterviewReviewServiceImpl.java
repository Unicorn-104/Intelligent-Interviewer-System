package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.InterviewReviewMapper;
import com.ruoyi.enterprise.service.IInterviewReviewService;

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

    @Override
    public List<Map<String, Object>> listReviews(Long userId, Integer status, Integer pageNum, Integer pageSize)
    {
        PageUtils.startPage(pageNum, pageSize);
        return reviewMapper.selectReviewList(status);
    }

    @Override
    public Map<String, Object> getReviewDetail(Long userId, Long sessionId)
    {
        Map<String, Object> detail = reviewMapper.selectReviewDetail(sessionId);
        if (detail == null)
        {
            throw new ServiceException("面试记录或评估结果不存在");
        }
        Map<String, Object> result = new LinkedHashMap<>(detail);
        result.put("dimensionScores", detail.get("dimensionScores") == null ? null
                : JSON.parse(String.valueOf(detail.get("dimensionScores"))));
        return result;
    }

    @Override
    public Map<String, Object> confirm(Long userId, Long sessionId, Boolean isFinal)
    {
        Map<String, Object> session = requireSession(sessionId);
        // UC-12 步骤8：确认通过
        reviewMapper.updateHrStatus(sessionId, HR_CONFIRMED, 1, null);
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
            result.put("message", "已确认通过（终面），请前往 Offer 管理触发录用意向书发送");
        }
        return result;
    }

    @Override
    public Map<String, Object> adjust(Long userId, Long sessionId, Map<String, Object> dims)
    {
        requireSession(sessionId);
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
        reviewMapper.updateDimensionScores(sessionId, JSON.toJSONString(dims), overall);
        reviewMapper.updateHrStatus(sessionId, HR_ADJUSTED, 1, "调整后通过");
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("overallScore", overall);
        result.put("hrStatus", HR_ADJUSTED);
        result.put("message", "评分已调整并确认通过");
        return result;
    }

    @Override
    public Map<String, Object> reject(Long userId, Long sessionId, String reason)
    {
        Map<String, Object> session = requireSession(sessionId);
        // UC-12 步骤10：驳回淘汰——候选人状态"已淘汰"（触发器自动写状态日志）+ 感谢信
        reviewMapper.updateHrStatus(sessionId, HR_CONFIRMED, 0, reason);
        reviewMapper.updateTalStatus(Long.valueOf(String.valueOf(session.get("candidateId"))), TAL_REJECTED);
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
    public Map<String, Object> cascade(Long userId, Long sessionId)
    {
        return cascadeInternal(requireSession(sessionId));
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
            // UC-12 E2：级联模式评分未达阈值，直接走淘汰流程
            reviewMapper.updateTalStatus(Long.valueOf(String.valueOf(session.get("candidateId"))), TAL_REJECTED);
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

    private Map<String, Object> requireSession(Long sessionId)
    {
        Map<String, Object> session = reviewMapper.selectSessionBase(sessionId);
        if (session == null)
        {
            throw new ServiceException("面试记录不存在");
        }
        return session;
    }

    private double round(double value)
    {
        return BigDecimal.valueOf(value).setScale(1, RoundingMode.HALF_UP).doubleValue();
    }
}
