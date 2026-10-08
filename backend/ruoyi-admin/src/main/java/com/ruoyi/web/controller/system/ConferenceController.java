package com.ruoyi.web.controller.system;

import java.util.HashMap;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.IConferenceService;

/**
 * 视频会议（面试链路：会议准备 / 进行中 / 结束 / 录制回放）
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/system/conference")
public class ConferenceController extends BaseController
{
    @Autowired
    private IConferenceService conferenceService;

    /**
     * 当前用户进行中 / 待开始的面试场次上下文（无场次返回空对象）
     */
    @GetMapping("/session/current")
    public AjaxResult currentSession()
    {
        return success(conferenceService.getCurrentSession(getUserId()));
    }

    /**
     * 指定场次的会议上下文
     */
    @GetMapping("/session/{sessionId}")
    public AjaxResult sessionContext(@PathVariable Long sessionId)
    {
        return success(conferenceService.getSessionContext(getUserId(), sessionId));
    }

    /**
     * 会议链接匿名校验（仅返回脱敏的邀请信息，用于统一入口页）
     */
    @Anonymous
    @GetMapping("/link/verify")
    public AjaxResult verifyLink(@RequestParam(required = false) String token)
    {
        return success(conferenceService.verifyRoomToken(token));
    }

    /**
     * 登录后按会议链接令牌进入场次
     */
    @PostMapping("/link/join")
    public AjaxResult joinLink(@RequestBody Map<String, Object> body)
    {
        return success(conferenceService.joinByRoomToken(getUserId(), str(body, "token")));
    }

    /**
     * HR 生成 / 复用会议链接
     */
    @PostMapping("/link")
    public AjaxResult createLink(@RequestBody Map<String, Object> body)
    {
        return success(conferenceService.createRoomLink(getUserId(), longOf(body, "peerUserId"),
                longOf(body, "positionId"), intOf(body, "durationMinutes"), intOf(body, "mode")));
    }

    /**
     * 候选人在本企业投递过的岗位（HR 发起面试时选择岗位）
     */
    @GetMapping("/link/positions")
    public AjaxResult linkPositions(@RequestParam Long peerUserId)
    {
        return success(conferenceService.listCandidatePositions(getUserId(), peerUserId));
    }

    /**
     * 等候室状态（双方各自的会前检测与就绪情况）
     */
    @GetMapping("/session/{sessionId}/waiting-room")
    public AjaxResult waitingRoom(@PathVariable Long sessionId)
    {
        return success(conferenceService.getWaitingRoom(getUserId(), sessionId));
    }

    /**
     * 上报本人会前检测与就绪状态
     */
    @PutMapping("/session/{sessionId}/participant-state")
    public AjaxResult participantState(@PathVariable Long sessionId, @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.reportParticipantState(getUserId(), sessionId, body));
    }

    /**
     * 会前环境检测结果上报（摄像头/麦克风/网络/扬声器 + 弱网风险标记）
     */
    @PostMapping("/session/{sessionId}/environment-check")
    public AjaxResult environmentCheck(@PathVariable Long sessionId, @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.reportEnvironmentCheck(getUserId(), sessionId, body));
    }

    /**
     * 提交录制知情同意（1-同意，2-拒绝）
     */
    @PostMapping("/session/{sessionId}/consent")
    public AjaxResult consent(@PathVariable Long sessionId, @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.submitConsent(getUserId(), sessionId, intOf(body, "consent")));
    }

    /**
     * 开始面试（候选人完成预检并同意录制后，由 HR 触发）
     */
    @PostMapping("/session/{sessionId}/start")
    public AjaxResult start(@PathVariable Long sessionId)
    {
        return success(conferenceService.startSession(getUserId(), sessionId));
    }

    /**
     * 面试进度与当前题目
     */
    @GetMapping("/session/{sessionId}/progress")
    public AjaxResult progress(@PathVariable Long sessionId)
    {
        return success(conferenceService.getProgress(getUserId(), sessionId));
    }

    /**
     * 提交作答
     */
    @PostMapping("/session/{sessionId}/answers")
    public AjaxResult answer(@PathVariable Long sessionId, @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.submitAnswer(getUserId(), sessionId, body));
    }

    /**
     * 更新音视频设备状态
     */
    @PutMapping("/session/{sessionId}/media")
    public AjaxResult media(@PathVariable Long sessionId, @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.updateMedia(getUserId(), sessionId, body));
    }

    /**
     * 心跳（弱网 / 断网判定）
     */
    @PostMapping("/session/{sessionId}/heartbeat")
    public AjaxResult heartbeat(@PathVariable Long sessionId)
    {
        return success(conferenceService.heartbeat(getUserId(), sessionId));
    }

    /**
     * 增量拉取实时字幕
     */
    @GetMapping("/session/{sessionId}/captions")
    public AjaxResult captions(@PathVariable Long sessionId,
            @RequestParam(required = false) Integer afterSequence,
            @RequestParam(required = false) Integer limit)
    {
        return success(conferenceService.getCaptions(getUserId(), sessionId, afterSequence, limit));
    }

    /**
     * 增量拉取提词器建议
     */
    @GetMapping("/session/{sessionId}/copilot")
    public AjaxResult copilot(@PathVariable Long sessionId,
            @RequestParam(required = false) Integer afterSequence,
            @RequestParam(required = false) Integer limit)
    {
        return success(conferenceService.getCopilot(getUserId(), sessionId, afterSequence, limit));
    }

    /**
     * 处理提词器建议（adopt-采纳，edit-编辑后采纳，ignore-忽略）
     */
    @PostMapping("/session/{sessionId}/copilot/{id}/handle")
    public AjaxResult handleCopilot(@PathVariable Long sessionId, @PathVariable Long id,
            @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.handleCopilot(getUserId(), sessionId, id, str(body, "action"), str(body, "content")));
    }

    /**
     * HR 接管 / 交还（start-接管，end-交还）
     */
    @PostMapping("/session/{sessionId}/takeover")
    public AjaxResult takeover(@PathVariable Long sessionId, @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.takeover(getUserId(), sessionId, str(body, "action"), str(body, "reason")));
    }

    /**
     * 正常结束面试
     */
    @PostMapping("/session/{sessionId}/finish")
    public AjaxResult finish(@PathVariable Long sessionId, @RequestBody(required = false) Map<String, Object> body)
    {
        String endReason = body == null ? null : str(body, "endReason");
        return success(conferenceService.finishSession(getUserId(), sessionId, endReason));
    }

    /**
     * 异常终止面试（silence-长时间无有效语音，offline-断网超时）
     */
    @PostMapping("/session/{sessionId}/abort")
    public AjaxResult abort(@PathVariable Long sessionId, @RequestBody(required = false) Map<String, Object> body)
    {
        String reason = body == null ? null : str(body, "reason");
        return success(conferenceService.abortSession(getUserId(), sessionId, reason));
    }

    /**
     * 面试结果（时长、完成题目数、报告状态）
     */
    @GetMapping("/session/{sessionId}/result")
    public AjaxResult result(@PathVariable Long sessionId)
    {
        return success(conferenceService.getSessionResult(getUserId(), sessionId));
    }

    /**
     * 录制文件列表（企业范围内）
     */
    @GetMapping("/recordings")
    public AjaxResult recordings(@RequestParam(required = false) Long sessionId,
            @RequestParam(required = false) String candidate,
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to)
    {
        Map<String, Object> query = new HashMap<>();
        query.put("sessionId", sessionId);
        query.put("candidate", candidate);
        query.put("from", from);
        query.put("to", to);
        return success(conferenceService.listRecordings(getUserId(), query));
    }

    /**
     * 存储空间占用
     */
    @GetMapping("/recordings/storage")
    public AjaxResult storage()
    {
        return success(conferenceService.getStorageUsage(getUserId()));
    }

    /**
     * 回放详情（含时间轴 / 章节打点）
     */
    @GetMapping("/recordings/{sessionId}")
    public AjaxResult playback(@PathVariable Long sessionId)
    {
        return success(conferenceService.getRecordingDetail(getUserId(), sessionId));
    }

    /**
     * 更新录制访问授权
     */
    @PostMapping("/recordings/{sessionId}/access")
    public AjaxResult access(@PathVariable Long sessionId, @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.updateRecordingAccess(getUserId(), sessionId,
                intOf(body, "validDays"), intOf(body, "level")));
    }

    /**
     * 发送下载验证码
     */
    @PostMapping("/recordings/{sessionId}/download-code")
    public AjaxResult downloadCode(@PathVariable Long sessionId)
    {
        return success(conferenceService.sendDownloadCode(getUserId(), sessionId));
    }

    /**
     * 校验下载验证码并返回录制地址
     */
    @PostMapping("/recordings/{sessionId}/download")
    public AjaxResult download(@PathVariable Long sessionId, @RequestBody Map<String, Object> body)
    {
        return success(conferenceService.verifyDownloadCode(getUserId(), sessionId, str(body, "code")));
    }

    /**
     * 查询录制存储策略
     */
    @GetMapping("/storage-policy")
    public AjaxResult storagePolicy()
    {
        return success(conferenceService.getStoragePolicy(getUserId()));
    }

    /**
     * 保存录制存储策略
     */
    @PutMapping("/storage-policy")
    public AjaxResult saveStoragePolicy(@RequestBody Map<String, Object> body)
    {
        return success(conferenceService.saveStoragePolicy(getUserId(),
                intOf(body, "keepDays"), intOf(body, "maxStorageGb")));
    }

    private static Integer intOf(Map<String, Object> body, String key)
    {
        Object value = body.get(key);
        if (value == null)
        {
            return null;
        }
        return value instanceof Number ? ((Number) value).intValue() : Integer.valueOf(value.toString());
    }

    private static String str(Map<String, Object> body, String key)
    {
        Object value = body.get(key);
        return value == null ? null : value.toString();
    }

    private static Long longOf(Map<String, Object> body, String key)
    {
        Object value = body.get(key);
        if (value == null)
        {
            return null;
        }
        return value instanceof Number ? ((Number) value).longValue() : Long.valueOf(value.toString());
    }
}