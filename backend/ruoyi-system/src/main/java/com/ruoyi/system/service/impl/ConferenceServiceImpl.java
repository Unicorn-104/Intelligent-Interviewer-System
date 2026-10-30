package com.ruoyi.system.service.impl;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.time.DateTimeException;
import java.time.LocalDate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.IInterviewScheduleService;
import com.ruoyi.enterprise.service.ITalentPoolService;
import com.ruoyi.enterprise.service.TalStatusService;
import com.ruoyi.system.config.AsrProperties;
import com.ruoyi.system.mapper.ConferenceMapper;
import com.ruoyi.system.service.IConferenceService;
import com.ruoyi.system.service.ILiveKitEgressService;

/**
 * 视频会议（面试链路）服务层实现
 *
 * @author ruoyi
 */
@Service
public class ConferenceServiceImpl implements IConferenceService
{
    /** 对话角色：AI面试官 */
    private static final int ROLE_AI = 1;
    /** 对话角色：候选人 */
    private static final int ROLE_CANDIDATE = 3;

    /** 参与者角色（t_int_participant_state.pst_role）：面试官/HR */
    private static final int ROLE_INTERVIEWER = 1;
    /** 参与者角色：候选人 */
    private static final int ROLE_CANDIDATE_PARTICIPANT = 2;

    /** 未指定时长时的默认面试时长（分钟） */
    private static final int DEFAULT_INTERVIEW_MINUTES = 45;
    /** 面试时长上限（分钟），避免异常时长把日历/预约时间拉得不可控 */
    private static final int MAX_INTERVIEW_MINUTES = 480;
    /** 面试模式：1-纯AI，2-AI+单面试官，3-AI+多面试官，4-无AI纯人工 */
    private static final int MODE_AI_ONLY = 1;
    private static final int MODE_AI_ONE = 2;
    private static final int MODE_AI_MULTI = 3;
    private static final int MODE_HUMAN_ONLY = 4;
    /** 默认面试模式：AI + 单面试官 */
    private static final int DEFAULT_INTERVIEW_MODE = MODE_AI_ONE;

    /** 下载验证码缓存前缀 */
    private static final String DOWNLOAD_CODE_KEY = "conference:download:code:";
    /** 下载验证码有效期（秒） */
    private static final int DOWNLOAD_CODE_TTL = 300;
    /** 面试问题参考提示：无提纲时按岗位技能生成的提示条数上限 */
    private static final int MAX_QUESTION_HINTS = 6;
    /** 非主面试官允许兜底开启面试的宽限期（毫秒）：预约开始时间后 5 分钟 */
    private static final long START_GRACE_MS = 5 * 60 * 1000L;

    /** 录制码率估算值（Kbps），用于把录制时长换算成存储占用 */
    private static final int RECORDING_BITRATE_KBPS = 1500;
    /** 默认保留天数 / 存储上限（GB） */
    private static final int DEFAULT_KEEP_DAYS = 90;
    private static final int DEFAULT_MAX_STORAGE_GB = 500;

    /** Egress 录制文件在容器内的输出根目录（对应宿主 D:/ruoyi/uploadPath/upload/recording） */
    private static final String EGRESS_OUTPUT_ROOT = "/out";

    @Autowired
    private ConferenceMapper conferenceMapper;

    /** 查看候选人简历/生成面试参考提示时复用人才库既有简历查询能力 */
    @Autowired
    private ITalentPoolService talentPoolService;

    @Autowired
    private TalStatusService talStatusService;

    @Autowired
    private RedisCache redisCache;

    @Autowired
    private ILiveKitEgressService liveKitEgressService;

    @Autowired
    private AsrProperties asrProperties;

    /** 面试预约统一取消入口：重新发起面试时释放旧预约时段并恢复候选人/投递状态 */
    @Autowired
    private IInterviewScheduleService scheduleService;

    /** 面试预约口径的投递状态推进（重新发起后同步「已约面」） */
    @Autowired
    private ScreeningMapper screeningMapper;

    @Override
    public Map<String, Object> getCurrentSession(Long userId)
    {
        Map<String, Object> ctx = conferenceMapper.selectCurrentSession(userId);
        if (ctx == null || ctx.isEmpty())
        {
            return new LinkedHashMap<>();
        }
        ctx.put("role", userId.equals(toLong(ctx.get("candidateUserId"))) ? "CANDIDATE" : "HR");
        conferenceMapper.ensureMeetingState(toLong(ctx.get("sessionId")));
        decorateInterviewers(ctx, toLong(ctx.get("sessionId")));
        return ctx;
    }

    @Override
    public List<Map<String, Object>> listCandidateSchedule(Long userId, String from, String to)
    {
        LocalDate startDate = parseScheduleDate(from, LocalDate.now().withDayOfMonth(1));
        LocalDate endDate = parseScheduleDate(to, startDate.plusMonths(1));
        if (!startDate.isBefore(endDate))
        {
            throw new ServiceException("面试日程日期范围无效");
        }
        if (startDate.plusMonths(3).isBefore(endDate))
        {
            throw new ServiceException("面试日程查询范围不能超过 3 个月");
        }

        Map<String, Object> params = new HashMap<>();
        params.put("userId", userId);
        params.put("from", startDate + " 00:00:00");
        params.put("to", endDate + " 00:00:00");
        return conferenceMapper.selectCandidateSchedule(params);
    }

    @Override
    public Map<String, Object> getSessionContext(Long userId, Long sessionId)
    {
        return requireAccess(userId, sessionId);
    }

    @Override
    public Map<String, Object> verifyRoomToken(String token)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        Map<String, Object> ctx = StringUtils.isEmpty(token) ? null : conferenceMapper.selectSessionByRoomToken(token);
        if (ctx == null || ctx.isEmpty())
        {
            result.put("valid", false);
            result.put("reason", "invalid");
            return result;
        }
        int status = toInt(ctx.get("status"));
        boolean valid = status <= 1;
        int mode = toInt(ctx.get("mode"));
        result.put("valid", valid);
        result.put("status", status);
        result.put("reason", valid ? null : "finished");
        result.put("mode", mode);
        result.put("modeName", modeName(mode));
        result.put("companyName", ctx.get("companyName"));
        result.put("positionTitle", ctx.get("positionTitle"));
        result.put("candidateName", ctx.get("candidateName"));
        result.put("interviewerName", ctx.get("interviewerName"));
        result.put("appointmentStartAt", ctx.get("appointmentStartAt"));
        result.put("appointmentEndAt", ctx.get("appointmentEndAt"));
        result.put("expiresTip", valid ? "面试结束前均可通过本链接进入" : "本场面试已结束");
        return result;
    }

    @Override
    public Map<String, Object> joinByRoomToken(Long userId, String token)
    {
        Map<String, Object> ctx = StringUtils.isEmpty(token) ? null : conferenceMapper.selectSessionByRoomToken(token);
        if (ctx == null || ctx.isEmpty())
        {
            throw new ServiceException("会议链接无效或已失效");
        }
        if (toInt(ctx.get("status")) >= 2)
        {
            throw new ServiceException("本场面试已结束");
        }
        return requireAccess(userId, toLong(ctx.get("sessionId")));
    }

    @Override
    @Transactional
    public Map<String, Object> createRoomLink(Long userId, Long peerUserId, Long positionId, Long stageId,
            Integer durationMinutes, Integer mode, List<Long> interviewerIds)
    {
        if (peerUserId == null)
        {
            throw new ServiceException("请选择要面试的候选人");
        }
        if (peerUserId.equals(userId))
        {
            throw new ServiceException("不能给本人发起面试");
        }
        Long companyId = resolveCompanyId(userId);
        // 候选人必须属于当前企业，避免拿到其他企业候选人时越权发起面试
        Map<String, Object> talent = conferenceMapper.selectTalentByUserId(peerUserId, companyId);
        if (talent == null || talent.isEmpty())
        {
            throw new ServiceException("该联系人不是本企业候选人，无法发起视频面试");
        }
        Long candidateId = toLong(talent.get("candidateId"));

        if (positionId == null)
        {
            throw new ServiceException("请选择面试岗位");
        }
        Long positionCompanyId = conferenceMapper.selectPositionCompanyId(positionId);
        if (positionCompanyId == null || !positionCompanyId.equals(companyId))
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        // 初筛淘汰/已撤回的投递不允许再发起面试
        if (conferenceMapper.countSchedulableApplication(candidateId, positionId) == 0)
        {
            throw new ServiceException("该投递已初筛淘汰或已撤回，无法发起面试");
        }
        // 面试阶段可空；传了就必须属于该岗位的流程模板
        Map<String, Object> stage = findStage(positionId, companyId, stageId);

        // 面试方式只接受 1~4；非法值直接报错，避免静默回落成「AI + 单面试官」与前端所选不一致
        if (mode != null && (mode < MODE_AI_ONLY || mode > MODE_HUMAN_ONLY))
        {
            throw new ServiceException("面试方式不合法");
        }
        int interviewMode = mode == null ? DEFAULT_INTERVIEW_MODE : mode;
        // 面试时长：不传用默认值；传了必须在合理区间内，避免 0 或超大值写入预约时间
        if (durationMinutes != null && (durationMinutes < 1 || durationMinutes > MAX_INTERVIEW_MINUTES))
        {
            throw new ServiceException("面试时长需在 1~" + MAX_INTERVIEW_MINUTES + " 分钟之间");
        }
        int duration = durationMinutes == null ? DEFAULT_INTERVIEW_MINUTES : durationMinutes;
        List<Long> selected = normalizeInterviewers(interviewerIds);
        validateInterviewerCount(interviewMode, selected.size());
        validateInterviewerScope(userId, selected);

        // 每次发起都新建场次并签发新的随机链接：先把该候选人此前尚未结束的场次与待面试预约清理掉，
        // 保证同一候选人同一时间只有一个活跃场次，且日历上不残留重复的「待面试」。
        // 旧预约逐个经面试调度服务的统一取消逻辑处理：释放关联时段、恢复候选人/投递状态；
        // 已取消/已完成的历史预约由该入口静默跳过，不阻断会议创建。
        conferenceMapper.abortActiveSessionsByCandidate(candidateId, companyId);
        for (Long oldAppointmentId : conferenceMapper.selectPendingAppointmentIds(candidateId, companyId))
        {
            scheduleService.cancelForRelaunch(userId, oldAppointmentId);
        }

        // 场次通过 ses_appointment_id 强制关联预约记录（该列 NOT NULL 且唯一）
        // 纯AI 无面试官时，面试官字段回落到发起人，仅用于满足非空约束与发起人权限
        Long sessionInterviewerId = selected.isEmpty() ? userId : selected.get(0);
        Map<String, Object> appointment = new HashMap<>();
        appointment.put("candidateId", candidateId);
        appointment.put("positionId", positionId);
        appointment.put("interviewerId", sessionInterviewerId);
        appointment.put("durationMinutes", duration);
        putStage(appointment, stage);
        conferenceMapper.insertAppointment(appointment);

        Map<String, Object> session = new HashMap<>();
        session.put("appointmentId", toLong(appointment.get("appointmentId")));
        session.put("candidateId", candidateId);
        session.put("positionId", positionId);
        session.put("interviewerId", sessionInterviewerId);
        session.put("mode", interviewMode);
        // 流程轮次与所选阶段顺序保持一致，未选阶段时按第一轮处理
        session.put("cascadeRound", stage == null || stage.get("sortOrder") == null ? 1 : toInt(stage.get("sortOrder")));
        conferenceMapper.insertSession(session);

        // 发起面试后自动把候选人流程状态推进为「面试中」，已淘汰/已录用的终态不会回退
        if (!talStatusService.change(candidateId, TalStatusService.TAL_INTERVIEWING,
                List.of(TalStatusService.TAL_NEW, TalStatusService.TAL_SCREENED, TalStatusService.TAL_INTERVIEWING,
                        TalStatusService.TAL_EXAM_PASSED),
                positionId, null, "发起视频面试", userId))
        {
            throw new ServiceException("候选人已淘汰或已录用，无法发起面试");
        }

        Long sessionId = toLong(session.get("sessionId"));
        String roomId = "INTERVIEW-" + sessionId;
        String roomToken = randomToken();
        saveRoomToken(sessionId, roomId, roomToken);

        // 每位被指派面试官：仅写入场次面试官关联（首位为主面试官），预约统一复用主预约，
        // 避免同一时间给同一候选人生成多条重复行程
        for (int i = 0; i < selected.size(); i++)
        {
            Map<String, Object> link = new HashMap<>();
            link.put("sessionId", sessionId);
            link.put("userId", selected.get(i));
            link.put("isPrimary", i == 0 ? 1 : 0);
            conferenceMapper.insertSessionInterviewer(link);
        }

        Map<String, Object> ctx = conferenceMapper.selectSessionContext(sessionId);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("roomId", roomId);
        result.put("roomToken", roomToken);
        result.put("token", roomToken);
        result.put("companyName", ctx.get("companyName"));
        result.put("positionTitle", ctx.get("positionTitle"));
        result.put("candidateName", ctx.get("candidateName"));
        result.put("appointmentStartAt", ctx.get("appointmentStartAt"));
        result.put("appointmentEndAt", ctx.get("appointmentEndAt"));
        result.put("durationMinutes", ctx.get("durationMinutes"));
        result.put("mode", ctx.get("mode"));
        result.put("status", ctx.get("status"));
        result.put("interviewers", conferenceMapper.selectSessionInterviewers(sessionId));
        return result;
    }

    @Override
    public List<Map<String, Object>> listInterviewers(Long userId)
    {
        Map<String, Object> params = new HashMap<>();
        params.put("companyId", resolveCompanyId(userId));
        params.put("userId", userId);
        return conferenceMapper.selectCompanyEmployees(params);
    }

    @Override
    public Map<String, Object> joinInterviewer(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        if (!"HR".equals(ctx.get("role")))
        {
            throw new ServiceException("仅面试官可加入本次面试");
        }
        // 兼容旧场次：尚无关联记录时补写一条，按 ses_interviewer_id 判定主面试官
        if (!isAssignedInterviewer(userId, sessionId))
        {
            Map<String, Object> link = new HashMap<>();
            link.put("sessionId", sessionId);
            link.put("userId", userId);
            link.put("isPrimary", userId.equals(toLong(ctx.get("interviewerId"))) ? 1 : 0);
            conferenceMapper.insertSessionInterviewer(link);
        }
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("userId", userId);
        params.put("mutedAv", 0);
        conferenceMapper.markSessionInterviewerJoined(params);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("joined", true);
        result.put("interviewers", conferenceMapper.selectSessionInterviewers(sessionId));
        return result;
    }

    @Override
    @Transactional
    public Map<String, Object> transferPrimary(Long userId, Long sessionId, Long targetUserId)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        if (!isPrimaryInterviewer(ctx, userId, sessionId))
        {
            throw new ServiceException("仅主面试官可移交主持人");
        }
        if (targetUserId == null || targetUserId.equals(userId))
        {
            throw new ServiceException("请选择另一位面试官作为移交对象");
        }
        if (!isAssignedInterviewer(targetUserId, sessionId))
        {
            throw new ServiceException("该用户不是本场次面试官");
        }
        conferenceMapper.clearSessionInterviewerPrimary(sessionId);
        Map<String, Object> link = new HashMap<>();
        link.put("sessionId", sessionId);
        link.put("userId", targetUserId);
        link.put("isPrimary", 1);
        conferenceMapper.insertSessionInterviewer(link);
        conferenceMapper.updateSessionPrimaryInterviewer(sessionId, targetUserId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("primaryInterviewerId", targetUserId);
        result.put("interviewers", conferenceMapper.selectSessionInterviewers(sessionId));
        return result;
    }

    /**
     * 面试官ID去重并剔除空值
     */
    private List<Long> normalizeInterviewers(List<Long> interviewerIds)
    {
        LinkedHashSet<Long> set = new LinkedHashSet<>();
        if (interviewerIds != null)
        {
            for (Long id : interviewerIds)
            {
                if (id != null)
                {
                    set.add(id);
                }
            }
        }
        return new ArrayList<>(set);
    }

    /**
     * 按面试模式校验面试官人数（模式严格联动人数）
     */
    private void validateInterviewerCount(int mode, int count)
    {
        switch (mode)
        {
            case MODE_AI_ONLY:
                if (count != 0)
                {
                    throw new ServiceException("纯AI面试无需选择面试官");
                }
                break;
            case MODE_AI_ONE:
                if (count != 1)
                {
                    throw new ServiceException("AI + 单面试官模式需选择 1 位面试官");
                }
                break;
            case MODE_AI_MULTI:
                if (count < 2)
                {
                    throw new ServiceException("AI + 多面试官模式需选择至少 2 位面试官");
                }
                break;
            case MODE_HUMAN_ONLY:
                if (count < 1)
                {
                    throw new ServiceException("无AI纯人工模式需选择至少 1 位面试官");
                }
                break;
            default:
                break;
        }
    }

    /**
     * 校验所选面试官均属于发起人所在企业（与面试官选择器数据源保持一致）
     */
    private void validateInterviewerScope(Long userId, List<Long> selected)
    {
        if (selected.isEmpty())
        {
            return;
        }
        LinkedHashSet<Long> allowed = new LinkedHashSet<>();
        for (Map<String, Object> item : listInterviewers(userId))
        {
            allowed.add(toLong(item.get("userId")));
        }
        for (Long interviewerId : selected)
        {
            if (!allowed.contains(interviewerId))
            {
                throw new ServiceException("所选面试官不属于当前企业，无法指派");
            }
        }
    }

    /**
     * 当前用户收到的面试邀约通知（消息中心「面试预约通知」系统会话）
     */
    @Override
    public List<Map<String, Object>> listInterviewerNotices(Long userId)
    {
        return conferenceMapper.selectInterviewerNotices(userId);
    }

    /**
     * 面试官回应邀约：接受（1）或拒绝（2）被指派
     */
    @Override
    public Map<String, Object> respondInterviewNotice(Long userId, Long sessionId, boolean accept)
    {
        if (!isAssignedInterviewer(userId, sessionId))
        {
            throw new ServiceException("您不是本场次面试官，无法回应邀约");
        }
        int acceptStatus = accept ? 1 : 2;
        conferenceMapper.updateInterviewerAcceptStatus(sessionId, userId, acceptStatus);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("acceptStatus", acceptStatus);
        return result;
    }

    @Override
    public List<Map<String, Object>> listCandidatePositions(Long userId, Long peerUserId)
    {
        if (peerUserId == null)
        {
            return new ArrayList<>();
        }
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> params = new HashMap<>();
        params.put("peerUserId", peerUserId);
        params.put("companyId", companyId);
        List<Map<String, Object>> positions = conferenceMapper.selectCandidatePositionsByPeer(params);
        // 附带每个岗位流程模板的阶段列表，供发起面试时选择阶段并按阶段带出默认设置
        for (Map<String, Object> position : positions)
        {
            Map<String, Object> stageParams = new HashMap<>();
            stageParams.put("positionId", position.get("positionId"));
            stageParams.put("companyId", companyId);
            position.put("stages", conferenceMapper.selectStagesByPosition(stageParams));
        }
        return positions;
    }

    @Override
    public Map<String, Object> getWaitingRoom(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireAccess(userId, sessionId);
        List<Map<String, Object>> participants = conferenceMapper.selectParticipantStates(sessionId);
        Map<String, Object> self = null;
        Map<String, Object> peer = null;
        for (Map<String, Object> item : participants)
        {
            if (userId.equals(toLong(item.get("userId"))))
            {
                self = item;
            }
            else
            {
                peer = item;
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("sessionStatus", ctx.get("status"));
        result.put("role", ctx.get("role"));
        result.put("self", self == null ? new LinkedHashMap<>() : self);
        result.put("peer", peer == null ? new LinkedHashMap<>() : peer);
        result.put("peerReady", peer != null && toInt(peer.get("ready")) == 1);
        result.put("peerName", peer == null ? null : peer.get("userName"));
        result.put("selfReady", self != null && toInt(self.get("ready")) == 1);
        result.put("participants", participants);
        return result;
    }

    @Override
    public Map<String, Object> reportParticipantState(Long userId, Long sessionId, Map<String, Object> body)
    {
        Map<String, Object> ctx = requireAccess(userId, sessionId);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("userId", userId);
        params.put("role", "CANDIDATE".equals(ctx.get("role")) ? ROLE_CANDIDATE_PARTICIPANT : ROLE_INTERVIEWER);
        params.put("camStatus", toInt(body.get("camStatus")));
        params.put("micStatus", toInt(body.get("micStatus")));
        params.put("speakerStatus", toInt(body.get("speakerStatus")));
        params.put("netStatus", toInt(body.get("netStatus")));
        params.put("rttMs", body.get("rttMs") == null ? null : toInt(body.get("rttMs")));
        params.put("bandwidthKbps", body.get("bandwidthKbps") == null ? null : toInt(body.get("bandwidthKbps")));
        params.put("riskFlag", toInt(body.get("riskFlag")));
        params.put("ready", toInt(body.get("ready")));
        Object devices = body.get("deviceIds");
        if (devices != null)
        {
            params.put("deviceJson", JSON.toJSONString(devices));
        }
        conferenceMapper.upsertParticipantState(params);
        return getWaitingRoom(userId, sessionId);
    }

    @Override
    public Map<String, Object> reportEnvironmentCheck(Long userId, Long sessionId, Map<String, Object> body)
    {
        requireAccess(userId, sessionId);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("camStatus", toInt(body.get("camStatus")));
        params.put("micStatus", toInt(body.get("micStatus")));
        params.put("speakerStatus", toInt(body.get("speakerStatus")));
        params.put("netStatus", toInt(body.get("netStatus")));
        params.put("rttMs", body.get("rttMs") == null ? null : toInt(body.get("rttMs")));
        params.put("bandwidthKbps", body.get("bandwidthKbps") == null ? null : toInt(body.get("bandwidthKbps")));
        params.put("riskFlag", toInt(body.get("riskFlag")));
        Object devices = body.get("deviceIds");
        if (devices != null)
        {
            params.put("deviceJson", JSON.toJSONString(devices));
        }
        conferenceMapper.updateEnvironmentCheck(params);
        return meetingState(sessionId);
    }

    @Override
    public Map<String, Object> submitConsent(Long userId, Long sessionId, Integer consent)
    {
        requireParticipant(userId, sessionId, true);
        if (consent == null || (consent != 1 && consent != 2))
        {
            throw new ServiceException("同意状态仅支持 1-同意 / 2-拒绝");
        }
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("consent", consent);
        conferenceMapper.updateConsent(params);
        return getSessionContext(userId, sessionId);
    }

    @Override
    public Map<String, Object> startSession(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        if (toInt(ctx.get("consent")) != 1)
        {
            throw new ServiceException("候选人尚未同意面试录制告知");
        }
        if ("HR".equals(ctx.get("role")))
        {
            // 主面试官可随时开启；非主面试官须等到预约开始时间 5 分钟后兜底开启
            assertPrimaryOrGrace(ctx, userId, sessionId, "开启");
        }
        if (toInt(ctx.get("status")) == 0)
        {
            conferenceMapper.startSession(sessionId);
        }
        return getSessionContext(userId, sessionId);
    }

    @Override
    public Map<String, Object> getProgress(Long userId, Long sessionId)
    {
        requireAccess(userId, sessionId);
        Map<String, Object> state = meetingState(sessionId);
        int total = toInt(state.get("totalQuestionNo"));
        int answered = toInt(state.get("answeredCount"));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("sessionStatus", state.get("sessionStatus"));
        result.put("totalQuestionNo", total);
        result.put("answeredCount", answered);
        result.put("currentQuestionNo", total > 0 ? Math.min(answered + 1, total) : answered + 1);
        result.put("elapsedSeconds", state.get("elapsedSeconds"));
        result.put("remainingSeconds", state.get("remainingSeconds"));
        result.put("takeover", state.get("takeover"));
        result.put("takeoverReason", state.get("takeoverReason"));
        if (total > 0 && answered < total)
        {
            Map<String, Object> params = new HashMap<>();
            params.put("sessionId", sessionId);
            params.put("offset", answered);
            result.put("question", conferenceMapper.selectOutlineAt(params));
        }
        return result;
    }

    @Override
    @Transactional
    public Map<String, Object> submitAnswer(Long userId, Long sessionId, Map<String, Object> body)
    {
        requireParticipant(userId, sessionId, true);
        String content = str(body.get("content"));
        if (StringUtils.isEmpty(content))
        {
            throw new ServiceException("作答内容不能为空");
        }
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("order", conferenceMapper.selectNextDialogueOrder(sessionId));
        params.put("role", ROLE_CANDIDATE);
        params.put("type", body.get("answerType") == null ? 1 : toInt(body.get("answerType")));
        params.put("content", content);
        conferenceMapper.insertDialogue(params);
        conferenceMapper.incrementAnswered(sessionId);
        return getProgress(userId, sessionId);
    }

    @Override
    public Map<String, Object> updateMedia(Long userId, Long sessionId, Map<String, Object> body)
    {
        requireAccess(userId, sessionId);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("micEnabled", toSwitch(body.get("microphoneEnabled")));
        params.put("camEnabled", toSwitch(body.get("cameraEnabled")));
        params.put("speakerVolume", body.get("speakerVolume") == null ? null : toInt(body.get("speakerVolume")));
        Object devices = body.get("deviceIds");
        if (devices != null)
        {
            params.put("deviceJson", JSON.toJSONString(devices));
        }
        conferenceMapper.updateMediaState(params);
        return meetingState(sessionId);
    }

    @Override
    public Map<String, Object> heartbeat(Long userId, Long sessionId)
    {
        requireAccess(userId, sessionId);
        conferenceMapper.touchHeartbeat(sessionId);
        Map<String, Object> state = meetingState(sessionId);
        state.put("serverTime", DateUtils.parseDateToStr(DateUtils.YYYY_MM_DD_HH_MM_SS, DateUtils.getNowDate()));
        return state;
    }

    @Override
    public List<Map<String, Object>> getCaptions(Long userId, Long sessionId, Long afterSequence, Integer limit)
    {
        requireAccess(userId, sessionId);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("afterSequence", afterSequence == null ? 0L : afterSequence);
        params.put("limit", normalizeLimit(limit, 50));
        return conferenceMapper.selectCaptions(params);
    }

    @Override
    public Map<String, Object> getAsrStatus(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireAccess(userId, sessionId);
        int mode = toInt(ctx.get("mode"));
        int status = toInt(ctx.get("status"));
        boolean aiInterview = mode >= MODE_AI_ONLY && mode <= MODE_AI_MULTI;
        String reason = null;
        if (!aiInterview)
        {
            reason = "该面试未启用 AI 实时字幕";
        }
        else if (status >= 2)
        {
            reason = "面试已结束";
        }
        else if (!asrProperties.isReady())
        {
            reason = asrProperties.getUnavailableReason();
        }
        Map<String, Object> result = new HashMap<>();
        result.put("enabled", reason == null);
        result.put("reason", reason);
        result.put("mode", mode);
        result.put("aiInterview", aiInterview);
        result.put("provider", asrProperties.getProvider());
        result.put("sampleRate", 16000);
        result.put("channels", 1);
        result.put("format", "pcm16le");
        return result;
    }

    @Override
    public Map<String, Object> issueAsrTicket(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        int mode = toInt(ctx.get("mode"));
        int status = toInt(ctx.get("status"));
        if (mode < MODE_AI_ONLY || mode > MODE_AI_MULTI)
        {
            throw new ServiceException("该面试未启用 AI 实时字幕");
        }
        if (status >= 2)
        {
            throw new ServiceException("面试已结束，无法开启实时字幕");
        }
        if (!asrProperties.isReady())
        {
            throw new ServiceException(asrProperties.getUnavailableReason());
        }
        String role = String.valueOf(ctx.get("role"));
        if (!"CANDIDATE".equals(role) && !"HR".equals(role))
        {
            throw new ServiceException("当前角色不可发送语音字幕");
        }
        String ticket = UUID.randomUUID().toString().replace("-", "");
        Map<String, Object> payload = new HashMap<>();
        payload.put("sessionId", sessionId);
        payload.put("userId", userId);
        payload.put("role", role);
        redisCache.setCacheObject(ASR_TICKET_CACHE_PREFIX + ticket, JSON.toJSONString(payload), 60,
                TimeUnit.SECONDS);

        Map<String, Object> result = new HashMap<>();
        result.put("ticket", ticket);
        result.put("wsPath", "/ws/conference-asr");
        result.put("expiresInSeconds", 60);
        result.put("sampleRate", 16000);
        result.put("channels", 1);
        result.put("format", "pcm16le");
        result.put("provider", asrProperties.getProvider());
        return result;
    }

    @Override
    @Transactional
    public int appendAsrCaption(Long sessionId, String role, String content)
    {
        if (StringUtils.isEmpty(content))
        {
            return 0;
        }
        String text = content.trim();
        if (text.length() > 2000)
        {
            text = text.substring(0, 2000);
        }
        if (text.length() == 0)
        {
            return 0;
        }
        // 同一场次的两位发言人可能并发写入，锁定场次行后再取下一个序号，避免序号冲突
        conferenceMapper.lockSessionForUpdate(sessionId);
        Integer nextOrder = conferenceMapper.selectNextDialogueOrder(sessionId);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("order", nextOrder == null ? 1 : nextOrder);
        params.put("role", "HR".equals(role) ? 2 : ROLE_CANDIDATE);
        params.put("type", 1);
        params.put("content", text);
        params.put("intent", "asr");
        conferenceMapper.insertDialogue(params);
        Object id = params.get("id");
        return id == null ? 0 : toInt(id);
    }

    @Override
    public List<Map<String, Object>> getCopilot(Long userId, Long sessionId, Integer afterSequence, Integer limit)
    {
        requireAccess(userId, sessionId);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("afterSequence", afterSequence == null ? 0 : afterSequence);
        params.put("limit", normalizeLimit(limit, 20));
        return conferenceMapper.selectCopilot(params);
    }

    @Override
    public List<Map<String, Object>> getQuestionHints(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireAccess(userId, sessionId);
        List<Map<String, Object>> hints = new ArrayList<>();
        List<Map<String, Object>> outline = conferenceMapper.selectOutlineQuestions(sessionId);
        if (outline != null && !outline.isEmpty())
        {
            outline.forEach(item -> item.put("source", "outline"));
            hints.addAll(outline);
        }
        else
        {
            // 本场次暂无面试提纲时，优先按候选人简历生成个性化提问，其次按岗位技能生成
            Long candidateId = toLong(ctx.get("candidateId"));
            if (candidateId != null)
            {
                Map<String, Object> resume = talentPoolService.getTalentResume(userId, candidateId);
                appendProjectHints(hints, resume == null ? null : resume.get("projectList"));
                appendSkillHints(hints, resume == null ? null : resume.get("skills"), "简历技能考察");
            }
            if (hints.isEmpty())
            {
                appendSkillHints(hints, ctx.get("positionSkills"), "岗位技能考察");
            }
        }
        return applyHintPreference(hints, userId, toLong(ctx.get("companyId")));
    }

    /** 面试官采纳 / 忽略某条参考提示，用于偏好学习 */
    @Override
    public Map<String, Object> handleHintFeedback(Long userId, Long sessionId, Map<String, Object> body)
    {
        Map<String, Object> ctx = requireAccess(userId, sessionId);
        if (!"HR".equals(ctx.get("role")))
        {
            throw new ServiceException("仅面试官可反馈问题提示");
        }
        String hintKey = str(body.get("hintKey"));
        String action = str(body.get("action"));
        if (StringUtils.isEmpty(hintKey))
        {
            throw new ServiceException("提示标识不能为空");
        }
        if (!"adopt".equals(action) && !"ignore".equals(action))
        {
            throw new ServiceException("反馈动作仅支持 adopt / ignore");
        }
        Long companyId = toLong(ctx.get("companyId"));
        if (companyId == null)
        {
            companyId = resolveCompanyId(userId);
        }
        Map<String, Object> params = new HashMap<>();
        params.put("userId", userId);
        params.put("companyId", companyId);
        params.put("hintKey", hintKey);
        if ("adopt".equals(action))
        {
            conferenceMapper.upsertHintUsed(params);
        }
        else
        {
            conferenceMapper.upsertHintIgnored(params);
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("hintKey", hintKey);
        result.put("action", action);
        return result;
    }

    @Override
    public Map<String, Object> handleCopilot(Long userId, Long sessionId, Long id, String action, String content)
    {
        requireParticipant(userId, sessionId, false);
        Map<String, Object> item = conferenceMapper.selectCopilotById(id);
        if (item == null || item.isEmpty() || !sessionId.equals(toLong(item.get("sessionId"))))
        {
            throw new ServiceException("提词器建议不存在");
        }
        int status;
        String adopted = null;
        if ("adopt".equals(action))
        {
            status = 1;
        }
        else if ("edit".equals(action))
        {
            if (StringUtils.isEmpty(content))
            {
                throw new ServiceException("请填写编辑后的内容");
            }
            status = 2;
            adopted = content;
        }
        else if ("ignore".equals(action))
        {
            status = 3;
        }
        else
        {
            throw new ServiceException("不支持的处理动作：" + action);
        }
        Map<String, Object> params = new HashMap<>();
        params.put("id", id);
        params.put("status", status);
        params.put("adoptedContent", adopted);
        conferenceMapper.handleCopilot(params);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", id);
        result.put("status", status);
        result.put("adoptedContent", adopted);
        return result;
    }

    @Override
    public Map<String, Object> takeover(Long userId, Long sessionId, String action, String reason)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        if (!"HR".equals(ctx.get("role")))
        {
            throw new ServiceException("仅面试官可执行接管操作");
        }
        if (!"start".equals(action) && !"end".equals(action))
        {
            throw new ServiceException("接管动作仅支持 start / end");
        }
        int takeover = "start".equals(action) ? 1 : 0;
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("takeover", takeover);
        params.put("reason", reason);
        conferenceMapper.updateTakeover(params);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("takeover", takeover);
        result.put("reason", reason);
        return result;
    }

    @Override
    public Map<String, Object> finishSession(Long userId, Long sessionId, String endReason)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        if ("HR".equals(ctx.get("role")))
        {
            assertPrimaryOrGrace(ctx, userId, sessionId, "结束");
        }
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("status", 2);
        // 会议结束时收敛仍在进行的录制（停止 Egress 并回填状态），避免录制记录永远停在「录制中」
        settleActiveRecording(ctx, sessionId, false);
        conferenceMapper.finishSession(params);
        Map<String, Object> result = buildSessionResult(sessionId);
        result.put("endReason", StringUtils.isEmpty(endReason) ? "normal" : endReason);
        return result;
    }

    @Override
    @Transactional
    public Map<String, Object> abortSession(Long userId, Long sessionId, String reason)
    {
        requireParticipant(userId, sessionId, false);
        Map<String, Object> abortCtx = conferenceMapper.selectSessionContext(sessionId);
        settleActiveRecording(abortCtx, sessionId, true);
        conferenceMapper.abortSession(sessionId);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("order", conferenceMapper.selectNextDialogueOrder(sessionId));
        params.put("role", ROLE_AI);
        params.put("type", 3);
        params.put("intent", "abnormal_termination");
        params.put("content", "【系统】面试异常终止（" + ("offline".equals(reason) ? "断网超过 30 秒" : "超过 2 分钟未检测到有效语音")
                + "），已标记异常终止并通知 HR 人工复核。");
        conferenceMapper.insertDialogue(params);
        Map<String, Object> result = buildSessionResult(sessionId);
        result.put("abortReason", StringUtils.isEmpty(reason) ? "silence" : reason);
        return result;
    }

    @Override
    public Map<String, Object> getSessionResult(Long userId, Long sessionId)
    {
        requireAccess(userId, sessionId);
        return buildSessionResult(sessionId);
    }

    @Override
    public List<Map<String, Object>> listRecordings(Long userId, Map<String, Object> query)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> params = new HashMap<>();
        params.put("companyId", companyId);
        params.put("recordingId", query.get("recordingId") == null ? null : toLong(query.get("recordingId")));
        params.put("sessionId", query.get("sessionId") == null ? null : toLong(query.get("sessionId")));
        params.put("candidateId", query.get("candidateId") == null ? null : toLong(query.get("candidateId")));
        params.put("candidateUserId", query.get("candidateUserId") == null ? null : toLong(query.get("candidateUserId")));
        params.put("candidate", str(query.get("candidate")));
        params.put("from", str(query.get("from")));
        params.put("to", str(query.get("to")));
        return conferenceMapper.selectRecordingList(params);
    }

    @Override
    public Map<String, Object> getStorageUsage(Long userId)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> policy = storagePolicy(companyId);
        int maxGb = toInt(policy.get("maxStorageGb"));
        Map<String, Object> totals = conferenceMapper.selectRecordingStorageTotal(companyId);
        long seconds = toLong(totals == null ? null : totals.get("totalSeconds"));
        long bytes = toLong(totals == null ? null : totals.get("totalBytes"));
        long estSeconds = toLong(totals == null ? null : totals.get("estSeconds"));
        // 逐场次统计：有真实字节数的按字节算，仅有历史时长的按码率估算，避免只认一种口径导致整体失真
        double usedGb = bytes / 1024.0 / 1024 / 1024
                + estSeconds * (double) RECORDING_BITRATE_KBPS * 1000 / 8 / 1024 / 1024 / 1024;
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("usedGb", Math.round(usedGb * 10000) / 10000.0);
        result.put("maxGb", maxGb);
        result.put("usedSeconds", seconds);
        result.put("usedBytes", bytes);
        result.put("keepDays", policy.get("keepDays"));
        result.put("percent", maxGb > 0 ? Math.round(usedGb * 1000 / maxGb) / 10.0 : 0);
        return result;
    }

    @Override
    public Map<String, Object> getRecordingDetail(Long userId, Long recordingId)
    {
        requireRecordingAccess(userId, recordingId);
        Map<String, Object> detail = conferenceMapper.selectRecordingDetail(recordingId);
        if (detail == null || detail.isEmpty())
        {
            throw new ServiceException("录制记录不存在");
        }
        Long sessionId = toLong(detail.get("sessionId"));
        // 时间轴以本条录制的起点为基准，避免一场面试多次录制时时间点相互错位
        Map<String, Object> timelineParams = new HashMap<>();
        timelineParams.put("sessionId", sessionId);
        timelineParams.put("startAt", str(detail.get("startAt")));
        List<Map<String, Object>> timeline = conferenceMapper.selectRecordingTimeline(timelineParams);
        List<Map<String, Object>> chapters = new ArrayList<>();
        List<Map<String, Object>> qa = new ArrayList<>();
        for (Map<String, Object> item : timeline)
        {
            Map<String, Object> point = new LinkedHashMap<>();
            point.put("second", item.get("second"));
            point.put("title", item.get("content"));
            point.put("role", item.get("role"));
            if (toInt(item.get("role")) == ROLE_CANDIDATE)
            {
                qa.add(point);
            }
            else
            {
                chapters.add(point);
            }
        }
        detail.put("chapters", chapters);
        detail.put("qa", qa);
        // 面试官列表：优先取场次面试官关联表，旧场次无关联记录时回落到主面试官
        List<Map<String, Object>> interviewers = conferenceMapper.selectSessionInterviewers(sessionId);
        if (interviewers.isEmpty() && StringUtils.isNotEmpty(str(detail.get("primaryInterviewerName"))))
        {
            Map<String, Object> primary = new LinkedHashMap<>();
            primary.put("userName", detail.get("primaryInterviewerName"));
            primary.put("isPrimary", 1);
            interviewers = new ArrayList<>();
            interviewers.add(primary);
        }
        detail.put("interviewers", interviewers);
        return detail;
    }

    @Override
    public Map<String, Object> updateRecordingAccess(Long userId, Long recordingId, Integer validDays, Integer level)
    {
        requireRecordingAccess(userId, recordingId);
        if (validDays == null || validDays <= 0)
        {
            throw new ServiceException("访问有效期必须大于 0 天");
        }
        if (level == null || level < 1 || level > 3)
        {
            throw new ServiceException("权限级别仅支持 1-仅HR/面试官，2-含管理员，3-候选人可见");
        }
        Map<String, Object> params = new HashMap<>();
        params.put("recordingId", recordingId);
        params.put("validDays", validDays);
        params.put("level", level);
        conferenceMapper.updateRecordingAccess(params);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordingId", recordingId);
        result.put("validDays", validDays);
        result.put("level", level);
        return result;
    }

    @Override
    public Map<String, Object> sendDownloadCode(Long userId, Long recordingId)
    {
        Map<String, Object> ctx = requireRecordingAccess(userId, recordingId);
        if (StringUtils.isEmpty(str(ctx.get("recUrl"))))
        {
            throw new ServiceException("该录制暂无文件，无法下载");
        }
        String code = String.valueOf((int) ((Math.random() * 9 + 1) * 100000));
        redisCache.setCacheObject(downloadCodeKey(userId, recordingId), code, DOWNLOAD_CODE_TTL, TimeUnit.SECONDS);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("expiresInSeconds", DOWNLOAD_CODE_TTL);
        // TODO 接入短信通道后移除 devCode（当前无短信服务，仅便于本地联调）
        result.put("devCode", code);
        return result;
    }

    @Override
    public Map<String, Object> verifyDownloadCode(Long userId, Long recordingId, String code)
    {
        Map<String, Object> ctx = requireRecordingAccess(userId, recordingId);
        String cacheKey = downloadCodeKey(userId, recordingId);
        Object cached = redisCache.getCacheObject(cacheKey);
        if (cached == null)
        {
            throw new ServiceException("验证码已过期，请重新获取");
        }
        if (StringUtils.isEmpty(code) || !code.equals(cached.toString()))
        {
            throw new ServiceException("验证码不正确");
        }
        redisCache.deleteObject(cacheKey);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("url", ctx.get("recUrl"));
        result.put("expiresInSeconds", DOWNLOAD_CODE_TTL);
        return result;
    }

    @Override
    public Map<String, Object> getStoragePolicy(Long userId)
    {
        return storagePolicy(resolveCompanyId(userId));
    }

    @Override
    public Map<String, Object> saveStoragePolicy(Long userId, Integer keepDays, Integer maxStorageGb)
    {
        Long companyId = resolveCompanyId(userId);
        if (keepDays == null || keepDays <= 0)
        {
            throw new ServiceException("保留天数必须大于 0");
        }
        if (maxStorageGb == null || maxStorageGb <= 0)
        {
            throw new ServiceException("存储上限必须大于 0");
        }
        Map<String, Object> params = new HashMap<>();
        params.put("companyId", companyId);
        params.put("keepDays", keepDays);
        params.put("maxStorageGb", maxStorageGb);
        conferenceMapper.upsertStoragePolicy(params);
        return storagePolicy(companyId);
    }

    @Override
    public Map<String, Object> startRecording(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        if ("HR".equals(ctx.get("role")))
        {
            // 录制为主面试官独占操作；非主面试官沿用预约时间 5 分钟宽限兜底规则
            assertPrimaryOrGrace(ctx, userId, sessionId, "开始录制");
        }
        if (toInt(ctx.get("status")) != 1)
        {
            throw new ServiceException("面试尚未开始，无法录制");
        }
        // 同一场次同时只允许一个录制任务：重复点击直接复用进行中的录制
        Map<String, Object> active = conferenceMapper.selectActiveRecording(sessionId);
        if (active != null && !active.isEmpty())
        {
            return active;
        }
        String room = StringUtils.isEmpty(str(ctx.get("roomId"))) ? "INTERVIEW-" + sessionId : str(ctx.get("roomId"));
        int seq = toInt(conferenceMapper.selectNextRecordingSeq(sessionId));
        // 编号格式：REC-<yyyyMMdd>-<场次ID补3位>-<场次内序号2位>，每次录制都是新的编号与文件
        String code = "REC-" + DateUtils.dateTime() + "-" + String.format("%03d", sessionId)
                + "-" + String.format("%02d", seq);
        String fileName = code + ".mp4";
        String datePath = DateUtils.datePath();

        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("code", code);
        params.put("seq", seq);
        params.put("url", Constants.RESOURCE_PREFIX + "/upload/recording/" + datePath + "/" + fileName);
        params.put("accessLevel", 1);
        conferenceMapper.insertRecording(params);
        Long recordingId = toLong(params.get("recordingId"));

        String egressId;
        try
        {
            egressId = liveKitEgressService.startRoomRecording(room,
                    EGRESS_OUTPUT_ROOT + "/" + datePath + "/" + fileName);
        }
        catch (RuntimeException e)
        {
            // 起录失败时把刚落库的录制记录标记为异常终止，避免留下永远「录制中」的脏记录
            conferenceMapper.abortRecordingBySession(sessionId);
            throw e;
        }
        Map<String, Object> egressParams = new HashMap<>();
        egressParams.put("recordingId", recordingId);
        egressParams.put("egressId", egressId);
        conferenceMapper.updateRecordingEgressId(egressParams);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordingId", recordingId);
        result.put("code", code);
        result.put("seq", seq);
        result.put("status", 0);
        result.put("egressId", egressId);
        return result;
    }

    @Override
    public Map<String, Object> stopRecording(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        if ("HR".equals(ctx.get("role")))
        {
            assertPrimaryOrGrace(ctx, userId, sessionId, "停止录制");
        }
        Map<String, Object> active = conferenceMapper.selectActiveRecording(sessionId);
        if (active == null || active.isEmpty())
        {
            throw new ServiceException("当前没有进行中的录制");
        }
        String egressId = str(active.get("egressId"));
        if (StringUtils.isNotEmpty(egressId))
        {
            liveKitEgressService.stopEgress(egressId);
        }
        // 先按录制起止墙钟时间回落为已完成，Egress 结束回调到达后再用真实时长 / 字节数覆盖
        Map<String, Object> params = new HashMap<>();
        params.put("recordingId", toLong(active.get("recordingId")));
        params.put("keepDays", toInt(storagePolicy(toLong(ctx.get("companyId"))).get("keepDays")));
        conferenceMapper.finishRecordingByRecordingId(params);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("recordingId", params.get("recordingId"));
        result.put("code", active.get("code"));
        result.put("status", 1);
        return result;
    }

    @Override
    public void handleLiveKitWebhook(Map<String, Object> payload)
    {
        if (payload == null || !"egress_ended".equals(str(payload.get("event"))))
        {
            return;
        }
        Object rawInfo = payload.get("egressInfo") != null ? payload.get("egressInfo") : payload.get("egress_info");
        Map<String, Object> info = valueAsMap(rawInfo);
        if (info == null)
        {
            return;
        }
        String egressId = str(info.get("egressId") != null ? info.get("egressId") : info.get("egress_id"));
        if (StringUtils.isEmpty(egressId))
        {
            return;
        }
        String status = str(info.get("status"));
        Map<String, Object> params = new HashMap<>();
        params.put("egressId", egressId);
        params.put("status", "EGRESS_FAILED".equals(status) || "EGRESS_ABORTED".equals(status) ? 2 : 1);
        Map<String, Object> file = resolveEgressFile(info);
        if (file != null)
        {
            Long sizeBytes = toLong(file.get("size"));
            Long durationNanos = toLong(file.get("duration"));
            params.put("sizeBytes", sizeBytes != null && sizeBytes > 0 ? sizeBytes : null);
            params.put("durationSec", durationNanos != null && durationNanos > 0
                    ? Integer.valueOf((int) (durationNanos / 1_000_000_000L)) : null);
            params.put("recUrl", resolveEgressUrl(str(file.get("filename"))));
        }
        params.put("keepDays", DEFAULT_KEEP_DAYS);
        conferenceMapper.finishRecordingByEgressId(params);
    }

    /**
     * 从 EgressInfo 中取出真正承载文件信息的对象：新版为 file_results[0].file，旧版为 file
     */
    private static Map<String, Object> resolveEgressFile(Map<String, Object> info)
    {
        Map<String, Object> direct = valueAsMap(info.get("file"));
        if (direct != null && (direct.containsKey("size") || direct.containsKey("filename")))
        {
            return direct;
        }
        Object results = info.get("fileResults") != null ? info.get("fileResults") : info.get("file_results");
        if (results instanceof List && !((List<?>) results).isEmpty())
        {
            Map<String, Object> item = valueAsMap(((List<?>) results).get(0));
            if (item != null)
            {
                Map<String, Object> nested = valueAsMap(item.get("file"));
                return nested == null ? item : nested;
            }
        }
        return direct;
    }

    /**
     * Egress 容器内输出路径（/out/...）映射为可被浏览器访问的静态资源地址
     */
    private static String resolveEgressUrl(String filename)
    {
        if (StringUtils.isEmpty(filename) || !filename.startsWith(EGRESS_OUTPUT_ROOT + "/"))
        {
            return null;
        }
        return Constants.RESOURCE_PREFIX + "/upload/recording" + filename.substring(EGRESS_OUTPUT_ROOT.length());
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> valueAsMap(Object value)
    {
        return value instanceof Map ? (Map<String, Object>) value : null;
    }

    /**
     * 场次结束时收敛仍在进行的录制：先停 Egress，再按正常 / 异常回填录制状态
     */
    private void settleActiveRecording(Map<String, Object> ctx, Long sessionId, boolean aborted)
    {
        Map<String, Object> active = conferenceMapper.selectActiveRecording(sessionId);
        if (active == null || active.isEmpty())
        {
            return;
        }
        String egressId = str(active.get("egressId"));
        if (StringUtils.isNotEmpty(egressId))
        {
            try
            {
                liveKitEgressService.stopEgress(egressId);
            }
            catch (Exception e)
            {
                // Egress 停止失败不阻断会议结束流程，录制状态仍按墙钟时长收敛
            }
        }
        if (aborted)
        {
            conferenceMapper.abortRecordingBySession(sessionId);
            return;
        }
        Map<String, Object> params = new HashMap<>();
        params.put("recordingId", toLong(active.get("recordingId")));
        params.put("keepDays", toInt(storagePolicy(ctx == null ? null : toLong(ctx.get("companyId"))).get("keepDays")));
        conferenceMapper.finishRecordingByRecordingId(params);
    }

    /**
     * 校验当前用户是否为该场次参与者（候选人 / 面试官），并确保会议状态记录存在
     *
     * @param candidateOnly 是否仅允许候选人
     */
    private Map<String, Object> requireParticipant(Long userId, Long sessionId, boolean candidateOnly)
    {
        Map<String, Object> ctx = conferenceMapper.selectSessionContext(sessionId);
        if (ctx == null || ctx.isEmpty())
        {
            throw new ServiceException("面试场次不存在");
        }
        boolean isCandidate = userId.equals(toLong(ctx.get("candidateUserId")));
        boolean isInterviewer = userId.equals(toLong(ctx.get("interviewerId"))) || isAssignedInterviewer(userId, sessionId);
        if (!isCandidate && !isInterviewer)
        {
            throw new ServiceException("无权访问该面试场次");
        }
        if (candidateOnly && !isCandidate)
        {
            throw new ServiceException("该操作仅限候选人执行");
        }
        ctx.put("role", isCandidate ? "CANDIDATE" : "HR");
        conferenceMapper.ensureMeetingState(sessionId);
        decorateInterviewers(ctx, sessionId);
        return ctx;
    }

    /**
     * 校验当前用户对该场次的访问权限：候选人、任一被指派面试官，或同企业观察者（OBSERVER）。
     * 用于只读 / 本人状态类接口，观察者不可执行面试官控制类操作。
     */
    private Map<String, Object> requireAccess(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = conferenceMapper.selectSessionContext(sessionId);
        if (ctx == null || ctx.isEmpty())
        {
            throw new ServiceException("面试场次不存在");
        }
        String role = resolveRole(userId, sessionId, ctx);
        if (role == null)
        {
            throw new ServiceException("无权访问该面试场次");
        }
        ctx.put("role", role);
        conferenceMapper.ensureMeetingState(sessionId);
        decorateInterviewers(ctx, sessionId);
        // 面试详情左栏：岗位技能标签与候选人真实流程记录，无数据时返回空列表由前端展示空态
        ctx.put("positionSkills", conferenceMapper.selectPositionSkills(toLong(ctx.get("positionId"))));
        ctx.put("flowHistory", conferenceMapper.selectCandidateFlowHistory(toLong(ctx.get("candidateId"))));
        return ctx;
    }

    /**
     * 解析用户在该场次中的角色：CANDIDATE / HR / OBSERVER，无权限返回 null
     */
    private String resolveRole(Long userId, Long sessionId, Map<String, Object> ctx)
    {
        if (userId.equals(toLong(ctx.get("candidateUserId"))))
        {
            return "CANDIDATE";
        }
        if (userId.equals(toLong(ctx.get("interviewerId"))) || isAssignedInterviewer(userId, sessionId))
        {
            return "HR";
        }
        Long sessionCompanyId = toLong(ctx.get("companyId"));
        if (sessionCompanyId != null && sessionCompanyId.equals(resolveCompanyId(userId)))
        {
            return "OBSERVER";
        }
        return null;
    }

    /**
     * 该用户是否为场次被指派面试官（关联表）
     */
    private boolean isAssignedInterviewer(Long userId, Long sessionId)
    {
        for (Map<String, Object> item : conferenceMapper.selectSessionInterviewers(sessionId))
        {
            if (userId.equals(toLong(item.get("userId"))))
            {
                return true;
            }
        }
        return false;
    }

    /**
     * 该用户是否为场次主面试官（无关联记录时回落到 ses_interviewer_id）
     */
    private boolean isPrimaryInterviewer(Map<String, Object> ctx, Long userId, Long sessionId)
    {
        Long primaryId = conferenceMapper.selectPrimaryInterviewerId(sessionId);
        if (primaryId == null)
        {
            primaryId = toLong(ctx.get("interviewerId"));
        }
        return userId.equals(primaryId);
    }

    /**
     * 主面试官可随时操作；非主面试官仅当已过预约开始时间 5 分钟后方可兜底操作
     */
    private void assertPrimaryOrGrace(Map<String, Object> ctx, Long userId, Long sessionId, String action)
    {
        if (isPrimaryInterviewer(ctx, userId, sessionId))
        {
            return;
        }
        java.util.Date startAt = DateUtils.parseDate(ctx.get("appointmentStartAt"));
        if (startAt == null || System.currentTimeMillis() < startAt.getTime() + START_GRACE_MS)
        {
            throw new ServiceException("仅主面试官可" + action + "本次面试，请等待主面试官操作，或于预约时间 5 分钟后重试");
        }
    }

    /**
     * 为场次上下文补充面试官列表与主面试官ID（供前端渲染与权限判断）
     */
    private void decorateInterviewers(Map<String, Object> ctx, Long sessionId)
    {
        List<Map<String, Object>> interviewers = conferenceMapper.selectSessionInterviewers(sessionId);
        ctx.put("interviewers", interviewers);
        Long primaryId = null;
        for (Map<String, Object> item : interviewers)
        {
            if (toInt(item.get("isPrimary")) == 1)
            {
                primaryId = toLong(item.get("userId"));
                break;
            }
        }
        // 纯AI 面试无人工面试官，session_interviewer 为空时主面试官不应回落到发起人
        if (primaryId == null && toInt(ctx.get("mode")) != MODE_AI_ONLY)
        {
            primaryId = toLong(ctx.get("interviewerId"));
        }
        ctx.put("primaryInterviewerId", primaryId);
    }

    /**
     * 录制访问校验：同企业、面试官，或候选人且访问级别为 3
     */
    private Map<String, Object> requireRecordingAccess(Long userId, Long recordingId)
    {
        Map<String, Object> ctx = recordingId == null ? null : conferenceMapper.selectRecordingAccessContext(recordingId);
        if (ctx == null || ctx.isEmpty())
        {
            throw new ServiceException("录制记录不存在");
        }
        Long userCompanyId = resolveCompanyId(userId);
        boolean allowed = userId.equals(toLong(ctx.get("interviewerId")))
                || userCompanyId.equals(toLong(ctx.get("companyId")))
                || (userId.equals(toLong(ctx.get("candidateUserId"))) && toInt(ctx.get("accessLevel")) == 3);
        if (!allowed)
        {
            throw new ServiceException("无权访问该录制文件");
        }
        return ctx;
    }

    /**
     * 会议状态（含剩余时长换算）
     */
    private Map<String, Object> meetingState(Long sessionId)
    {
        Map<String, Object> state = conferenceMapper.selectMeetingState(sessionId);
        if (state == null)
        {
            state = new LinkedHashMap<>();
        }
        int duration = toInt(state.get("durationSeconds"));
        int elapsed = toInt(state.get("elapsedSeconds"));
        state.put("remainingSeconds", Math.max(duration - elapsed, 0));
        return state;
    }

    /**
     * 面试结果
     */
    private Map<String, Object> buildSessionResult(Long sessionId)
    {
        Map<String, Object> result = conferenceMapper.selectSessionResult(sessionId);
        if (result == null)
        {
            result = new LinkedHashMap<>();
        }
        int total = toInt(result.get("totalQuestionNo"));
        int answered = toInt(result.get("answeredCount"));
        result.put("completionRate", total > 0 ? Math.round(answered * 1000.0 / total) / 10.0 : 0);
        result.put("reportStatus", toInt(result.get("reportGenerated")) > 0 ? "ready" : "generating");
        return result;
    }

    /** 校验所选阶段属于该岗位的流程模板；未选阶段返回 null */
    private Map<String, Object> findStage(Long positionId, Long companyId, Long stageId)
    {
        if (stageId == null)
        {
            return null;
        }
        Map<String, Object> params = new HashMap<>();
        params.put("positionId", positionId);
        params.put("companyId", companyId);
        for (Map<String, Object> item : conferenceMapper.selectStagesByPosition(params))
        {
            if (stageId.equals(toLong(item.get("stageId"))))
            {
                return item;
            }
        }
        throw new ServiceException("所选面试阶段与岗位不匹配");
    }

    /** 把阶段信息写入预约记录，落库到 apt_stage_id / apt_stage_name / apt_stage_type / apt_stage_order */
    private void putStage(Map<String, Object> target, Map<String, Object> stage)
    {
        target.put("stageId", stage == null ? null : toLong(stage.get("stageId")));
        target.put("stageName", stage == null ? null : stage.get("name"));
        target.put("stageType", stage == null || stage.get("type") == null ? null : toInt(stage.get("type")));
        target.put("stageOrder", stage == null || stage.get("sortOrder") == null ? null : toInt(stage.get("sortOrder")));
    }

    /**
     * 当前用户归属企业；未绑定企业时与其它企业端模块保持一致，回落到默认企业
     */
    private Long resolveCompanyId(Long userId)
    {
        Long companyId = conferenceMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }

    private LocalDate parseScheduleDate(String value, LocalDate fallback)
    {
        if (StringUtils.isEmpty(value))
        {
            return fallback;
        }
        try
        {
            return LocalDate.parse(value);
        }
        catch (DateTimeException ex)
        {
            throw new ServiceException("面试日程日期格式应为 yyyy-MM-dd");
        }
    }

    /**
     * 存储策略（企业级优先，缺省用全局默认）
     */
    private Map<String, Object> storagePolicy(Long companyId)
    {
        Map<String, Object> policy = conferenceMapper.selectStoragePolicy(companyId);
        if (policy == null || policy.isEmpty())
        {
            policy = new LinkedHashMap<>();
            policy.put("keepDays", DEFAULT_KEEP_DAYS);
            policy.put("maxStorageGb", DEFAULT_MAX_STORAGE_GB);
        }
        else
        {
            policy.put("keepDays", toInt(policy.get("keepDays")));
            policy.put("maxStorageGb", toInt(policy.get("maxStorageGb")));
        }
        return policy;
    }

    private String downloadCodeKey(Long userId, Long recordingId)
    {
        return DOWNLOAD_CODE_KEY + recordingId + ":" + userId;
    }

    /**
     * 为场次写入房间号与会议链接令牌
     */
    private void saveRoomToken(Long sessionId, String roomId, String roomToken)
    {
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("roomId", roomId);
        params.put("roomToken", roomToken);
        conferenceMapper.updateSessionRoomToken(params);
    }

    /**
     * 32 位随机会议链接令牌
     */
    private static String randomToken()
    {
        return UUID.randomUUID().toString().replace("-", "");
    }

    private int normalizeLimit(Integer limit, int defaultValue)
    {
        if (limit == null || limit <= 0)
        {
            return defaultValue;
        }
        return Math.min(limit, 200);
    }

    /**
     * 按面试官历史采纳 / 忽略记录排序参考提示：常采纳的前置，常忽略的后置，最多返回 6 条。
     * 无历史记录时保持原有顺序。
     */
    private List<Map<String, Object>> applyHintPreference(List<Map<String, Object>> hints, Long userId, Long companyId)
    {
        if (hints == null || hints.isEmpty())
        {
            return hints;
        }
        Map<String, int[]> prefs = new HashMap<>();
        if (userId != null && companyId != null)
        {
            List<Map<String, Object>> rows = conferenceMapper.selectHintPreferences(userId, companyId);
            if (rows != null)
            {
                for (Map<String, Object> row : rows)
                {
                    String key = str(row.get("hintKey"));
                    if (StringUtils.isEmpty(key))
                    {
                        continue;
                    }
                    prefs.put(key, new int[] { toInt(row.get("usedCount")), toInt(row.get("ignoredCount")) });
                }
            }
        }
        for (Map<String, Object> hint : hints)
        {
            int[] counts = prefs.get(str(hint.get("topic")));
            hint.put("usedCount", counts == null ? 0 : counts[0]);
            hint.put("ignoredCount", counts == null ? 0 : counts[1]);
        }
        hints.sort((a, b) -> hintScore(b) - hintScore(a));
        return hints.size() > MAX_QUESTION_HINTS ? new ArrayList<>(hints.subList(0, MAX_QUESTION_HINTS)) : hints;
    }

    private static int hintScore(Map<String, Object> hint)
    {
        return toIntStatic(hint.get("usedCount")) - toIntStatic(hint.get("ignoredCount")) * 2;
    }

    private static int toIntStatic(Object value)
    {
        return value instanceof Number ? ((Number) value).intValue() : 0;
    }

    /** 面试参考提示：由候选人项目经历生成（最多 2 条，避免挤占技能提示） */
    private void appendProjectHints(List<Map<String, Object>> hints, Object projects)
    {
        if (!(projects instanceof List<?>))
        {
            return;
        }
        int count = 0;
        for (Object item : (List<?>) projects)
        {
            if (count >= 2 || hints.size() >= MAX_QUESTION_HINTS)
            {
                break;
            }
            if (!(item instanceof Map<?, ?>))
            {
                continue;
            }
            String name = str(((Map<?, ?>) item).get("name"));
            if (StringUtils.isEmpty(name))
            {
                continue;
            }
            Map<String, Object> hint = new LinkedHashMap<>();
            hint.put("topic", "项目经历 · " + name);
            hint.put("hint", "请候选人介绍该项目的业务背景、本人承担的具体工作，以及可量化的最终结果。");
            hint.put("source", "resume");
            hints.add(hint);
            count++;
        }
    }

    /** 面试参考提示：由技能列表生成 */
    private void appendSkillHints(List<Map<String, Object>> hints, Object skills, String topicPrefix)
    {
        if (!(skills instanceof List<?>))
        {
            return;
        }
        for (Object item : (List<?>) skills)
        {
            if (hints.size() >= MAX_QUESTION_HINTS)
            {
                break;
            }
            String name = item instanceof Map<?, ?> ? str(((Map<?, ?>) item).get("name")) : str(item);
            if (StringUtils.isEmpty(name))
            {
                continue;
            }
            Map<String, Object> hint = new LinkedHashMap<>();
            hint.put("topic", topicPrefix + " · " + name);
            hint.put("hint", "请候选人说明在 " + name + " 上的实际使用场景、掌握程度与遇到的问题。");
            hint.put("source", "skill");
            hints.add(hint);
        }
    }

    private static String str(Object value)
    {
        return value == null ? null : value.toString();
    }

    private static Long toLong(Object value)
    {
        if (value == null)
        {
            return null;
        }
        return value instanceof Number ? ((Number) value).longValue() : Long.valueOf(value.toString());
    }

    private static int toInt(Object value)
    {
        if (value == null)
        {
            return 0;
        }
        return value instanceof Number ? ((Number) value).intValue() : Integer.parseInt(value.toString());
    }

    /**
     * 面试方式展示名（用于邀请链接页区分纯 AI / 含人工面试官）
     */
    private String modeName(int mode)
    {
        switch (mode)
        {
            case MODE_AI_ONLY:
                return "纯AI面试";
            case MODE_AI_ONE:
                return "AI+单面试官";
            case MODE_AI_MULTI:
                return "AI+多面试官";
            case MODE_HUMAN_ONLY:
                return "无AI纯人工";
            default:
                return "AI面试";
        }
    }

    /**
     * 布尔开关转 0/1，空值返回 null（不更新该字段）
     */
    private static Integer toSwitch(Object value)
    {
        if (value == null)
        {
            return null;
        }
        if (value instanceof Boolean)
        {
            return ((Boolean) value) ? 1 : 0;
        }
        return toInt(value);
    }
}
