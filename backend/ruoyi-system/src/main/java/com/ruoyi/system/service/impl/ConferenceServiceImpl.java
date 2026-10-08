package com.ruoyi.system.service.impl;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.mapper.ConferenceMapper;
import com.ruoyi.system.service.IConferenceService;

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
    /** 默认面试模式：AI + HR 协同 */
    private static final int DEFAULT_INTERVIEW_MODE = 2;

    /** 下载验证码缓存前缀 */
    private static final String DOWNLOAD_CODE_KEY = "conference:download:code:";
    /** 下载验证码有效期（秒） */
    private static final int DOWNLOAD_CODE_TTL = 300;
    /** 录制码率估算值（Kbps），用于把录制时长换算成存储占用 */
    private static final int RECORDING_BITRATE_KBPS = 1500;
    /** 默认保留天数 / 存储上限（GB） */
    private static final int DEFAULT_KEEP_DAYS = 90;
    private static final int DEFAULT_MAX_STORAGE_GB = 500;

    @Autowired
    private ConferenceMapper conferenceMapper;

    @Autowired
    private RedisCache redisCache;

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
        return ctx;
    }

    @Override
    public Map<String, Object> getSessionContext(Long userId, Long sessionId)
    {
        return requireParticipant(userId, sessionId, false);
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
        return requireParticipant(userId, toLong(ctx.get("sessionId")), false);
    }

    @Override
    @Transactional
    public Map<String, Object> createRoomLink(Long userId, Long peerUserId, Long positionId, Integer durationMinutes, Integer mode)
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

        Map<String, Object> query = new HashMap<>();
        query.put("candidateId", candidateId);
        query.put("interviewerId", userId);
        Map<String, Object> active = conferenceMapper.selectActiveSessionByCandidate(query);

        Long sessionId;
        String roomId;
        String roomToken;
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
            if (positionId == null)
            {
                throw new ServiceException("请选择面试岗位");
            }
            int duration = durationMinutes == null || durationMinutes <= 0 ? DEFAULT_INTERVIEW_MINUTES : durationMinutes;
            // 场次通过 ses_appointment_id 强制关联预约记录（该列 NOT NULL 且唯一）
            Map<String, Object> appointment = new HashMap<>();
            appointment.put("candidateId", candidateId);
            appointment.put("positionId", positionId);
            appointment.put("interviewerId", userId);
            appointment.put("durationMinutes", duration);
            conferenceMapper.insertAppointment(appointment);

            Map<String, Object> session = new HashMap<>();
            session.put("appointmentId", toLong(appointment.get("appointmentId")));
            session.put("candidateId", candidateId);
            session.put("positionId", positionId);
            session.put("interviewerId", userId);
            session.put("mode", mode == null || mode < 1 || mode > 2 ? DEFAULT_INTERVIEW_MODE : mode);
            conferenceMapper.insertSession(session);

            sessionId = toLong(session.get("sessionId"));
            roomId = "INTERVIEW-" + sessionId;
            roomToken = randomToken();
            saveRoomToken(sessionId, roomId, roomToken);
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
        result.put("status", ctx.get("status"));
        return result;
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
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
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
        Map<String, Object> ctx = requireParticipant(userId, sessionId, false);
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
        requireParticipant(userId, sessionId, false);
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
        if (toInt(ctx.get("status")) == 0)
        {
            conferenceMapper.startSession(sessionId);
        }
        return getSessionContext(userId, sessionId);
    }

    @Override
    public Map<String, Object> getProgress(Long userId, Long sessionId)
    {
        requireParticipant(userId, sessionId, false);
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
        requireParticipant(userId, sessionId, false);
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
        requireParticipant(userId, sessionId, false);
        conferenceMapper.touchHeartbeat(sessionId);
        Map<String, Object> state = meetingState(sessionId);
        state.put("serverTime", DateUtils.parseDateToStr(DateUtils.YYYY_MM_DD_HH_MM_SS, DateUtils.getNowDate()));
        return state;
    }

    @Override
    public List<Map<String, Object>> getCaptions(Long userId, Long sessionId, Integer afterSequence, Integer limit)
    {
        requireParticipant(userId, sessionId, false);
        Map<String, Object> params = new HashMap<>();
        params.put("sessionId", sessionId);
        params.put("afterSequence", afterSequence == null ? 0 : afterSequence);
        params.put("limit", normalizeLimit(limit, 50));
        return conferenceMapper.selectCaptions(params);
    }

    @Override
    public List<Map<String, Object>> getCopilot(Long userId, Long sessionId, Integer afterSequence, Integer limit)
    {
        requireParticipant(userId, sessionId, false);
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
        requireParticipant(userId, sessionId, false);
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
        requireParticipant(userId, sessionId, false);
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
        long seconds = toLong(conferenceMapper.selectRecordingSecondsTotal(companyId));
        // 码率估算：字节 = 秒 × 码率(Kbps) × 1000 ÷ 8
        double usedGb = seconds * (double) RECORDING_BITRATE_KBPS * 1000 / 8 / 1024 / 1024 / 1024;
        double used = Math.round(usedGb * 100) / 100.0;
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("usedGb", used);
        result.put("maxGb", maxGb);
        result.put("usedSeconds", seconds);
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
        boolean isInterviewer = userId.equals(toLong(ctx.get("interviewerId")));
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
        return ctx;
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