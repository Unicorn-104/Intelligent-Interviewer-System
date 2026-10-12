package com.ruoyi.system.service;

import java.util.List;
import java.util.Map;

/**
 * 视频会议（面试链路）服务层
 *
 * @author ruoyi
 */
public interface IConferenceService
{
    /**
     * 当前用户进行中 / 待开始的面试场次上下文（无场次时返回空 Map）
     */
    public Map<String, Object> getCurrentSession(Long userId);

    /**
     * 指定场次的会议上下文（含角色：HR / CANDIDATE）
     */
    public Map<String, Object> getSessionContext(Long userId, Long sessionId);

    /**
     * 匿名校验会议链接令牌（仅返回脱敏的邀请信息，不含场次ID）
     */
    public Map<String, Object> verifyRoomToken(String token);

    /**
     * 登录后按会议链接令牌进入场次（返回场次上下文，含角色）
     */
    public Map<String, Object> joinByRoomToken(Long userId, String token);

    /**
     * HR 生成 / 复用会议链接（内部按需创建预约与场次）
     *
     * @param interviewerIds 被指派的面试官用户ID（按面试模式校验人数，纯AI 可为空）
     * @param candidateAppUrl 候选人端地址，用于在系统消息中拼接会议链接（可为空）
     */
    public Map<String, Object> createRoomLink(Long userId, Long peerUserId, Long positionId, Integer durationMinutes,
            Integer mode, List<Long> interviewerIds, String candidateAppUrl);

    /**
     * 本企业全体在职用户（HR 发起面试时选择面试官）
     */
    public List<Map<String, Object>> listInterviewers(Long userId);

    /**
     * 面试官加入会议（后到面试官点击「加入本次面试」，记录已加入状态）
     */
    public Map<String, Object> joinInterviewer(Long userId, Long sessionId);

    /**
     * 移交主面试官（仅现任主面试官可操作，接收人须为本场次面试官）
     */
    public Map<String, Object> transferPrimary(Long userId, Long sessionId, Long targetUserId);

    /**
     * 候选人在本企业投递过的岗位（HR 发起面试时选择岗位）
     */
    public List<Map<String, Object>> listCandidatePositions(Long userId, Long peerUserId);

    /**
     * 等候室状态（双方各自的会前检测与就绪情况）
     */
    public Map<String, Object> getWaitingRoom(Long userId, Long sessionId);

    /**
     * 上报本人会前检测与就绪状态
     */
    public Map<String, Object> reportParticipantState(Long userId, Long sessionId, Map<String, Object> body);

    /**
     * 上报会前环境检测结果
     */
    public Map<String, Object> reportEnvironmentCheck(Long userId, Long sessionId, Map<String, Object> body);

    /**
     * 提交录制知情同意
     *
     * @param consent 1-同意，2-拒绝
     */
    public Map<String, Object> submitConsent(Long userId, Long sessionId, Integer consent);

    /**
     * 开始面试（HR 触发，需候选人已同意录制告知）
     */
    public Map<String, Object> startSession(Long userId, Long sessionId);

    /**
     * 面试进度与当前题目
     */
    public Map<String, Object> getProgress(Long userId, Long sessionId);

    /**
     * 提交作答
     */
    public Map<String, Object> submitAnswer(Long userId, Long sessionId, Map<String, Object> body);

    /**
     * 更新音视频设备状态
     */
    public Map<String, Object> updateMedia(Long userId, Long sessionId, Map<String, Object> body);

    /**
     * 心跳（用于弱网 / 断网判定）
     */
    public Map<String, Object> heartbeat(Long userId, Long sessionId);

    /**
     * 增量拉取字幕
     */
    public List<Map<String, Object>> getCaptions(Long userId, Long sessionId, Integer afterSequence, Integer limit);

    /**
     * 增量拉取提词器建议
     */
    public List<Map<String, Object>> getCopilot(Long userId, Long sessionId, Integer afterSequence, Integer limit);

    /**
     * 处理提词器建议
     *
     * @param action adopt-采纳，edit-编辑后采纳，ignore-忽略
     */
    public Map<String, Object> handleCopilot(Long userId, Long sessionId, Long id, String action, String content);

    /**
     * HR 接管 / 交还
     *
     * @param action start-接管，end-交还
     */
    public Map<String, Object> takeover(Long userId, Long sessionId, String action, String reason);

    /**
     * 正常结束面试
     */
    public Map<String, Object> finishSession(Long userId, Long sessionId, String endReason);

    /**
     * 异常终止面试
     *
     * @param reason silence-长时间无有效语音，offline-断网超时
     */
    public Map<String, Object> abortSession(Long userId, Long sessionId, String reason);

    /**
     * 面试结果（时长、完成题目数、报告状态）
     */
    public Map<String, Object> getSessionResult(Long userId, Long sessionId);

    /**
     * 录制文件列表（企业范围内）
     */
    public List<Map<String, Object>> listRecordings(Long userId, Map<String, Object> query);

    /**
     * 存储空间占用
     */
    public Map<String, Object> getStorageUsage(Long userId);

    /**
     * 回放详情（含时间轴）
     */
    public Map<String, Object> getRecordingDetail(Long userId, Long sessionId);

    /**
     * 更新录制访问授权
     */
    public Map<String, Object> updateRecordingAccess(Long userId, Long sessionId, Integer validDays, Integer level);

    /**
     * 发送下载验证码
     */
    public Map<String, Object> sendDownloadCode(Long userId, Long sessionId);

    /**
     * 校验下载验证码并返回录制地址
     */
    public Map<String, Object> verifyDownloadCode(Long userId, Long sessionId, String code);

    /**
     * 查询录制存储策略
     */
    public Map<String, Object> getStoragePolicy(Long userId);

    /**
     * 保存录制存储策略
     */
    public Map<String, Object> saveStoragePolicy(Long userId, Integer keepDays, Integer maxStorageGb);
}