package com.ruoyi.enterprise.service;

import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.enums.ApplicationEndReason;
import com.ruoyi.common.enums.ApplicationStatus;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;

/**
 * 岗位投递维度状态机：t_app_record.app_status 的唯一合法变更入口。
 *
 * <p>提供状态合法性校验、流转守卫、终态保护、事务、行锁并发控制、幂等与状态变更日志；
 * 业务代码不得直接 update app_status 绕过本服务。HR 权限在 Controller 层用注解控制，
 * 本服务对“必须有操作人”的终止原因做强校验。</p>
 *
 * <p>合法流转：
 * 已投递→招聘中/未录用；招聘中→待发Offer/未录用；
 * 待发Offer→待确认Offer/未录用；待确认Offer→已录用/未录用；
 * 已录用、未录用为终态。</p>
 *
 * @author tqy
 */
@Service
public class ApplicationStatusService
{
    /** 操作来源，落 t_app_status_log.asl_source */
    public static final String SOURCE_HR = "HR";
    public static final String SOURCE_AI = "AI";
    public static final String SOURCE_EXAM = "EXAM";
    public static final String SOURCE_INTERVIEW = "INTERVIEW";
    public static final String SOURCE_OFFER = "OFFER";
    public static final String SOURCE_SCHEDULER = "SCHEDULER";
    public static final String SOURCE_WITHDRAW = "WITHDRAW";
    public static final String SOURCE_ADMIN = "ADMIN";

    /** 合法流转表：key 为当前状态，value 为可到达的目标状态 */
    private static final Map<ApplicationStatus, List<ApplicationStatus>> ALLOWED = new EnumMap<>(
            ApplicationStatus.class);

    static
    {
        ALLOWED.put(ApplicationStatus.APPLIED,
                List.of(ApplicationStatus.IN_PROGRESS, ApplicationStatus.NOT_HIRED));
        ALLOWED.put(ApplicationStatus.IN_PROGRESS,
                List.of(ApplicationStatus.PENDING_OFFER, ApplicationStatus.NOT_HIRED));
        ALLOWED.put(ApplicationStatus.PENDING_OFFER,
                List.of(ApplicationStatus.OFFER_PENDING_CONFIRMATION, ApplicationStatus.NOT_HIRED));
        ALLOWED.put(ApplicationStatus.OFFER_PENDING_CONFIRMATION,
                List.of(ApplicationStatus.HIRED, ApplicationStatus.NOT_HIRED));
    }

    private final ApplicationStatusMapper mapper;

    public ApplicationStatusService(ApplicationStatusMapper mapper)
    {
        this.mapper = mapper;
    }

    /**
     * 通用状态流转：加锁 → 守卫 → 更新 → 终止字段 → 日志 → 流程实例收尾。
     *
     * @param appId 岗位投递ID
     * @param target 目标状态
     * @param operatorId 操作人（系统事件可空）
     * @param source 操作来源
     * @param endReason 终止原因（仅目标为未录用时必填）
     * @param remark 变更/终止说明
     * @return true 已流转或幂等命中；非法流转抛 ServiceException
     */
    @Transactional(rollbackFor = Exception.class)
    public boolean transition(Long appId, ApplicationStatus target, Long operatorId, String source,
            ApplicationEndReason endReason, String remark)
    {
        if (appId == null) throw new ServiceException("岗位投递ID不能为空");
        if (target == null) throw new ServiceException("目标状态不能为空");
        Integer currentCode = mapper.lockAppStatus(appId);
        if (currentCode == null) throw new ServiceException("岗位投递记录不存在或已删除");
        ApplicationStatus current = ApplicationStatus.fromCode(currentCode);
        if (current == null) throw new ServiceException("当前投递状态无法识别，需人工核查：" + currentCode);

        // 幂等：已是目标状态，不重复写日志；未录用仅在首次终止缺原因时补写，不覆盖已有终止记录
        if (current == target)
        {
            if (target == ApplicationStatus.NOT_HIRED && !mapper.existsEndReason(appId))
                applyEndFields(appId, endReason, operatorId, remark);
            return true;
        }
        if (current.isTerminal())
            throw new ServiceException("当前为终态（" + current.getLabel() + "），普通业务操作不得变更");
        List<ApplicationStatus> reachable = ALLOWED.get(current);
        if (reachable == null || !reachable.contains(target))
            throw new ServiceException("不允许从「" + current.getLabel() + "」流转到「" + target.getLabel() + "」");

        validateReason(target, endReason, operatorId);

        if (mapper.updateAppStatus(appId, current.getCode(), target.getCode()) == 0)
            throw new ServiceException("投递状态已被并发修改，请刷新后重试");

        Map<String, Object> app = mapper.selectApplicationById(appId);
        Long candidateId = asLong(app.get("candidateId"));
        Long positionId = asLong(app.get("positionId"));
        String reasonText = endReason == null ? remark : endReason.getCode();

        if (target == ApplicationStatus.NOT_HIRED)
        {
            applyEndFields(appId, endReason, operatorId, remark);
            mapper.updateProcessInstanceStatus(candidateId, positionId, List.of(0), 3);
        }
        else if (target == ApplicationStatus.HIRED)
        {
            mapper.updateProcessInstanceStatus(candidateId, positionId, List.of(0), 1);
        }

        mapper.insertStatusLog(appId, candidateId, positionId, current.getCode(), target.getCode(),
                operatorId, source, reasonText);
        return true;
    }

    /** HR 启动第一个正式招聘环节：已投递→招聘中 */
    public boolean startRecruitment(Long appId, Long operatorId)
    {
        return transition(appId, ApplicationStatus.IN_PROGRESS, operatorId, SOURCE_HR, null, "HR 启动招聘流程");
    }

    /** 全部环节通过，HR 确认进入待发 Offer：招聘中→待发 Offer */
    public boolean passToPendingOffer(Long appId, Long operatorId)
    {
        return transition(appId, ApplicationStatus.PENDING_OFFER, operatorId, SOURCE_HR, null, "招聘环节通过");
    }

    /** Offer 真正发送成功：待发 Offer→待确认 Offer */
    public boolean offerSent(Long appId, Long operatorId)
    {
        return transition(appId, ApplicationStatus.OFFER_PENDING_CONFIRMATION, operatorId, SOURCE_OFFER,
                null, "Offer 已发送");
    }

    /** 候选人接受 Offer：待确认 Offer→已录用 */
    public boolean offerAccepted(Long appId, Long operatorId, String source)
    {
        return transition(appId, ApplicationStatus.HIRED, operatorId, source, null, "候选人接受 Offer");
    }

    /**
     * 进入未录用（终态）的统一入口，按业务事件带终止原因。
     *
     * @param endReason 终止原因编码
     */
    public boolean terminate(Long appId, ApplicationEndReason endReason, Long operatorId, String source,
            String remark)
    {
        return transition(appId, ApplicationStatus.NOT_HIRED, operatorId, source, endReason, remark);
    }

    /** 候选人撤回：按候选人+岗位定位投递，未录用，原因 CANDIDATE_WITHDRAWN */
    @Transactional(rollbackFor = Exception.class)
    public boolean withdraw(Long candidateId, Long positionId, Long operatorId)
    {
        Long appId = mapper.selectAppId(candidateId, positionId);
        if (appId == null) throw new ServiceException("岗位投递记录不存在，无法撤回");
        return terminate(appId, ApplicationEndReason.CANDIDATE_WITHDRAWN, operatorId, SOURCE_WITHDRAW,
                "候选人主动撤回");
    }

    /** 终止字段校验与写入 */
    private void applyEndFields(Long appId, ApplicationEndReason endReason, Long operatorId, String remark)
    {
        String reasonCode = endReason == null ? null : endReason.getCode();
        mapper.updateEndFields(appId, reasonCode, operatorId, remark);
    }

    /** 终止原因业务规则校验 */
    private void validateReason(ApplicationStatus target, ApplicationEndReason endReason, Long operatorId)
    {
        if (target == ApplicationStatus.NOT_HIRED)
        {
            if (endReason == null) throw new ServiceException("未录用必须记录终止原因");
            if (endReason == ApplicationEndReason.HR_REJECTED && operatorId == null)
                throw new ServiceException("HR 淘汰必须记录操作人");
            if (endReason == ApplicationEndReason.OFFER_CANCELLED && operatorId == null)
                throw new ServiceException("取消 Offer 必须记录 HR 操作人");
        }
        else if (endReason != null)
        {
            throw new ServiceException("只有未录用状态才允许填写终止原因");
        }
    }

    private Long asLong(Object value)
    {
        return value == null ? null : Long.valueOf(value.toString());
    }
}
