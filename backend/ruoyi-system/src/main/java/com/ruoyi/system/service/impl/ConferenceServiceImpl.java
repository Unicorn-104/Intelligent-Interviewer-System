package com.ruoyi.system.service.impl;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.mapper.ConferenceMapper;
import com.ruoyi.system.service.IConferenceService;
import com.ruoyi.system.service.IImService;

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
    /** 非主面试官允许兜底开启面试的宽限期（毫秒）：预约开始时间后 5 分钟 */
    private static final long START_GRACE_MS = 5 * 60 * 1000L;

    /** 录制码率估算值（Kbps），用于把录制时长换算成存储占用 */
    private static final int RECORDING_BITRATE_KBPS = 1500;
    /** 录制分片临时目录名（java.io.tmpdir 下，按场次分子目录） */
    private static final String RECORDING_CHUNK_DIR = "recruit-recording";
    /** 默认保留天数 / 存储上限（GB） */
    private static final int DEFAULT_KEEP_DAYS = 90;
    private static final int DEFAULT_MAX_STORAGE_GB = 500;

    @Autowired
    private ConferenceMapper conferenceMapper;

    @Autowired
    private RedisCache redisCache;

    @Autowired
    private IImService imService;

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
        result.put("valid", valid);
        result.put("status", status);
        result.put("reason", valid ? null : "finished");
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
    public Map<String, Object> createRoomLink(Long userId, Long peerUserId, Long positionId, Integer durationMinutes,
            Integer mode, List<Long> interviewerIds, String candidateAppUrl)
    {
        if (peerUserId == null)
        {
            throw new ServiceException("请选择要面试的候选人");
        }
        if (peerUserId.equals(userId))
        {
            throw new ServiceException("不能给本人发起面试");
        }
        Map<String, Object> talent = conferenceMapper.selectTalentByUserId(peerUserId);
        if (talent == null || talent.isEmpty())
        {
            throw new ServiceException("该联系人不是候选人，无法发起视频面试");
        }
        Long candidateId = toLong(talent.get("candidateId"));

        int interviewMode = mode == null || mode < MODE_AI_ONLY || mode > MODE_HUMAN_ONLY ? DEFAULT_INTERVIEW_MODE : mode;
        List<Long> selected = normalizeInterviewers(interviewerIds);
        validateInterviewerCount(interviewMode, selected.size());
        validateInterviewerScope(userId, selected);

        Map<String, Object> query = new HashMap<>();
        query.put("candidateId", candidateId);
        Map<String, Object> active = conferenceMapper.selectActiveSessionByCandidate(query);

        Long sessionId;
        String roomId;
        String roomToken;
        boolean created = false;
        if (active != null && !active.isEmpty())
        {
            // 已有未结束场次：复用，仅在缺少令牌时补写
            sessionId = toLong(active.get("sessionId"));
            roomId = str(active.get("roomId"));
            roomToken = str(active.get("roomToken"));
            if (StringUtils.isEmpty(roomToken))
            {
                roomId = StringUtils.isEmpty(roomId) ? "INTERVIEW-" + sessionId : roomId;
                roomToken = randomToken();
                saveRoomToken(sessionId, roomId, roomToken);
            }
        }
        else
        {
            created = true;
            if (positionId == null)
            {
                throw new ServiceException("请选择面试岗位");
            }
            int duration = durationMinutes == null || durationMinutes <= 0 ? DEFAULT_INTERVIEW_MINUTES : durationMinutes;
            // 场次通过 ses_appointment_id 强制关联预约记录（该列 NOT NULL 且唯一）
            // 纯AI 无面试官时，预约面试官回落到发起人，满足非空约束
            Long sessionInterviewerId = selected.isEmpty() ? userId : selected.get(0);
            Map<String, Object> appointment = new HashMap<>();
            appointment.put("candidateId", candidateId);
            appointment.put("positionId", positionId);
            appointment.put("interviewerId", sessionInterviewerId);
            appointment.put("durationMinutes", duration);
            conferenceMapper.insertAppointment(appointment);

            Map<String, Object> session = new HashMap<>();
            session.put("appointmentId", toLong(appointment.get("appointmentId")));
            session.put("candidateId", candidateId);
            session.put("positionId", positionId);
            session.put("interviewerId", sessionInterviewerId);
            session.put("mode", interviewMode);
            conferenceMapper.insertSession(session);

            sessionId = toLong(session.get("sessionId"));
            roomId = "INTERVIEW-" + sessionId;
            roomToken = randomToken();
            saveRoomToken(sessionId, roomId, roomToken);

            // 每位被指派面试官：写入关联（首位为主面试官）+ 各自一条面试行程
            for (int i = 0; i < selected.size(); i++)
            {
                Long interviewerId = selected.get(i);
                if (i > 0)
                {
                    Map<String, Object> extra = new HashMap<>();
                    extra.put("candidateId", candidateId);
                    extra.put("positionId", positionId);
                    extra.put("interviewerId", interviewerId);
                    extra.put("durationMinutes", duration);
                    conferenceMapper.insertAppointment(extra);
                }
                Map<String, Object> link = new HashMap<>();
                link.put("sessionId", sessionId);
                link.put("userId", interviewerId);
                link.put("isPrimary", i == 0 ? 1 : 0);
                conferenceMapper.insertSessionInterviewer(link);
            }
        }

        Map<String, Object> ctx = conferenceMapper.selectSessionContext(sessionId);
        if (created)
        {
            sendInterviewerNotices(userId, selected, candidateAppUrl, str(ctx.get("positionTitle")),
                    str(ctx.get("candidateName")), str(ctx.get("appointmentStartAt")), roomToken);
        }

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
     * 向被指派面试官推送面试信息（复用 IM 系统消息 type=5）
     */
    private void sendInterviewerNotices(Long senderId, List<Long> interviewerIds, String candidateAppUrl,
            String positionTitle, String candidateName, String startAt, String roomToken)
    {
        if (interviewerIds.isEmpty())
        {
            return;
        }
        String link = StringUtils.isEmpty(candidateAppUrl) ? null
                : candidateAppUrl + "/conference-join?token=" + roomToken;
        String content = "【面试邀约】您已被指派为「" + StringUtils.nvl(positionTitle, "岗位") + "」候选人 "
                + StringUtils.nvl(candidateName, "候选人") + " 的面试官，面试时间 " + StringUtils.nvl(startAt, "待定")
                + "。请准时进入会议。";
        if (link != null)
        {
            content += "会议链接：" + link;
        }
        for (Long interviewerId : interviewerIds)
        {
            if (interviewerId.equals(senderId))
            {
                continue;
            }
            ImMessage message = new ImMessage();
            message.setType(5);
            message.setContent(content);
            imService.sendMessage(message, senderId, interviewerId);
        }
    }

    @Override
    public List<Map<String, Object>> listCandidatePositions(Long userId, Long peerUserId)
    {
        if (peerUserId == null)
        {
            return new ArrayList<>();
        }
        Map<String, Object> params = new HashMap<>();
        params.put("peerUserId", peerUserId);
        params.put("companyId", resolveCompanyId(userId));
        return conferenceMapper.selectCandidatePositionsByPeer(params);
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
    public List<Map<String, Object>> getCaptions(Long userId, Long sessionId, Integer afterSequence, Integer limit)
    {
        requireAccess(userId, sessionId);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("afterSequence", afterSequence == null ? 0 : afterSequence);
        params.put("limit", normalizeLimit(limit, 50));
        return conferenceMapper.selectCaptions(params);
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
        params.put("sessionId", query.get("sessionId") == null ? null : toLong(query.get("sessionId")));
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
        // 优先按真实文件大小统计；历史数据无字节数时回落到按码率估算
        double usedGb = bytes > 0 ? bytes / 1024.0 / 1024 / 1024
                : seconds * (double) RECORDING_BITRATE_KBPS * 1000 / 8 / 1024 / 1024 / 1024;
        double used = Math.round(usedGb * 100) / 100.0;
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("usedGb", used);
        result.put("maxGb", maxGb);
        result.put("usedSeconds", seconds);
        result.put("usedBytes", bytes);
        result.put("keepDays", policy.get("keepDays"));
        result.put("percent", maxGb > 0 ? Math.round(used * 1000 / maxGb) / 10.0 : 0);
        return result;
    }

    @Override
    public Map<String, Object> getRecordingDetail(Long userId, Long sessionId)
    {
        requireRecordingAccess(userId, sessionId);
        Map<String, Object> detail = conferenceMapper.selectRecordingDetail(sessionId);
        if (detail == null || detail.isEmpty())
        {
            throw new ServiceException("面试场次不存在");
        }
        List<Map<String, Object>> timeline = conferenceMapper.selectRecordingTimeline(sessionId);
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
        return detail;
    }

    @Override
    public Map<String, Object> updateRecordingAccess(Long userId, Long sessionId, Integer validDays, Integer level)
    {
        requireRecordingAccess(userId, sessionId);
        if (validDays == null || validDays <= 0)
        {
            throw new ServiceException("访问有效期必须大于 0 天");
        }
        if (level == null || level < 1 || level > 3)
        {
            throw new ServiceException("权限级别仅支持 1-仅HR/面试官，2-含管理员，3-候选人可见");
        }
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("validDays", validDays);
        params.put("level", level);
        conferenceMapper.updateRecordingAccess(params);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("validDays", validDays);
        result.put("level", level);
        return result;
    }

    @Override
    public Map<String, Object> sendDownloadCode(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = requireRecordingAccess(userId, sessionId);
        if (StringUtils.isEmpty(str(ctx.get("recUrl"))))
        {
            throw new ServiceException("该场次暂无录制文件，无法下载");
        }
        String code = String.valueOf((int) ((Math.random() * 9 + 1) * 100000));
        redisCache.setCacheObject(downloadCodeKey(userId, sessionId), code, DOWNLOAD_CODE_TTL, TimeUnit.SECONDS);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("expiresInSeconds", DOWNLOAD_CODE_TTL);
        // TODO 接入短信通道后移除 devCode（当前无短信服务，仅便于本地联调）
        result.put("devCode", code);
        return result;
    }

    @Override
    public Map<String, Object> verifyDownloadCode(Long userId, Long sessionId, String code)
    {
        Map<String, Object> ctx = requireRecordingAccess(userId, sessionId);
        String cacheKey = downloadCodeKey(userId, sessionId);
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
    public Map<String, Object> uploadRecordingChunk(Long userId, Long sessionId,
            MultipartFile file, int index, boolean last, Integer durationSec)
    {
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
        if ("HR".equals(ctx.get("role")))
        {
            // 录制为主面试官独占操作；非主面试官沿用预约时间 5 分钟宽限兜底规则
            assertPrimaryOrGrace(ctx, userId, sessionId, "上传录制");
        }
        if (file == null || file.isEmpty() || index < 0)
        {
            throw new ServiceException("录制分片无效");
        }
        Path chunkDir = recordingChunkDir(sessionId);
        Path chunkFile = chunkDir.resolve("chunk_" + index + ".webm");
        try
        {
            Files.createDirectories(chunkDir);
            file.transferTo(chunkFile.toFile());
        }
        catch (Exception e)
        {
            throw new ServiceException("录制分片暂存失败：" + e.getMessage());
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("index", index);
        if (!last)
        {
            result.put("status", "chunked");
            return result;
        }
        // 末片到达：按序号拼接为完整文件并落盘到上传目录
        String recUrl = finalizeRecording(sessionId, chunkDir, durationSec, toLong(ctx.get("companyId")));
        result.put("status", "finalized");
        result.put("recUrl", recUrl);
        return result;
    }

    /**
     * 分片临时目录（位于 profile 目录之外，避免未完成的分片被 /profile/** 匿名下载）
     */
    private Path recordingChunkDir(Long sessionId)
    {
        return Paths.get(System.getProperty("java.io.tmpdir"), RECORDING_CHUNK_DIR, String.valueOf(sessionId));
    }

    /**
     * 按分片序号顺序拼接落盘，回写场次录制元数据，并清理临时分片与旧录制文件
     */
    private String finalizeRecording(Long sessionId, Path chunkDir, Integer durationSec, Long companyId)
    {
        List<Path> chunks = new ArrayList<>();
        try (Stream<Path> files = Files.list(chunkDir))
        {
            files.filter(p -> p.getFileName().toString().startsWith("chunk_")
                            && p.getFileName().toString().endsWith(".webm"))
                    .sorted(Comparator.comparingInt(p -> parseChunkIndex(p.getFileName().toString())))
                    .forEach(chunks::add);
        }
        catch (Exception e)
        {
            throw new ServiceException("读取录制分片失败：" + e.getMessage());
        }
        if (chunks.isEmpty())
        {
            throw new ServiceException("未找到录制分片");
        }
        String datePath = DateUtils.datePath();
        String fileName = UUID.randomUUID().toString().replace("-", "") + ".webm";
        File target = new File(RuoYiConfig.getUploadPath() + File.separator + "recording"
                + File.separator + datePath, fileName);
        if (!target.getParentFile().exists() && !target.getParentFile().mkdirs())
        {
            throw new ServiceException("创建录制目录失败");
        }
        long totalBytes = 0;
        try (OutputStream out = new FileOutputStream(target))
        {
            for (Path chunk : chunks)
            {
                Files.copy(chunk, out);
                totalBytes += Files.size(chunk);
            }
        }
        catch (Exception e)
        {
            throw new ServiceException("录制文件写入失败：" + e.getMessage());
        }
        // 重复录制时删除旧文件，避免孤儿文件占空间
        Map<String, Object> detail = conferenceMapper.selectRecordingDetail(sessionId);
        String oldUrl = detail == null ? null : str(detail.get("recUrl"));
        if (StringUtils.isNotEmpty(oldUrl))
        {
            File old = new File(RuoYiConfig.getProfile() + StringUtils.substringAfter(oldUrl, Constants.RESOURCE_PREFIX));
            if (old.exists() && !old.equals(target))
            {
                old.delete();
            }
        }
        int keepDays = toInt(storagePolicy(companyId).get("keepDays"));
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("recUrl", Constants.RESOURCE_PREFIX + "/upload/recording/" + datePath + "/" + fileName);
        params.put("durationSec", durationSec == null || durationSec < 0 ? 0 : durationSec);
        params.put("sizeBytes", totalBytes);
        params.put("keepDays", keepDays);
        conferenceMapper.updateRecordingFile(params);
        try
        {
            for (Path chunk : chunks)
            {
                Files.deleteIfExists(chunk);
            }
            Files.deleteIfExists(chunkDir);
        }
        catch (Exception e)
        {
            // 临时分片清理失败不影响录制结果
        }
        return (String) params.get("recUrl");
    }

    private static int parseChunkIndex(String fileName)
    {
        try
        {
            return Integer.parseInt(fileName.substring("chunk_".length(), fileName.length() - ".webm".length()));
        }
        catch (NumberFormatException e)
        {
            return Integer.MAX_VALUE;
        }
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
        ctx.put("primaryInterviewerId", primaryId == null ? toLong(ctx.get("interviewerId")) : primaryId);
    }

    /**
     * 录制访问校验：同企业、面试官，或候选人且访问级别为 3
     */
    private Map<String, Object> requireRecordingAccess(Long userId, Long sessionId)
    {
        Map<String, Object> ctx = conferenceMapper.selectSessionContext(sessionId);
        if (ctx == null || ctx.isEmpty())
        {
            throw new ServiceException("面试场次不存在");
        }
        Long userCompanyId = resolveCompanyId(userId);
        boolean allowed = userId.equals(toLong(ctx.get("interviewerId")))
                || userCompanyId.equals(toLong(ctx.get("companyId")))
                || (userId.equals(toLong(ctx.get("candidateUserId"))) && toInt(ctx.get("recAccessLevel")) == 3);
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

    /**
     * 当前用户归属企业；未绑定企业时与其它企业端模块保持一致，回落到默认企业
     */
    private Long resolveCompanyId(Long userId)
    {
        Long companyId = conferenceMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
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

    private String downloadCodeKey(Long userId, Long sessionId)
    {
        return DOWNLOAD_CODE_KEY + sessionId + ":" + userId;
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