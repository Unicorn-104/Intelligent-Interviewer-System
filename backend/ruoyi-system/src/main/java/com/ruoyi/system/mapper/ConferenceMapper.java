package com.ruoyi.system.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 视频会议（面试链路）数据层
 *
 * @author ruoyi
 */
public interface ConferenceMapper
{
    /**
     * 查询当前用户所属企业ID
     */
    public Long selectCompanyIdByUser(@Param("userId") Long userId);

    /**
     * 查询当前用户进行中 / 待开始的面试场次上下文
     */
    public Map<String, Object> selectCurrentSession(@Param("userId") Long userId);

    /**
     * 查询候选人在指定日期范围内的面试日程
     */
    public List<Map<String, Object>> selectCandidateSchedule(Map<String, Object> params);

    /**
     * 按场次ID查询面试场次上下文（含访问校验所需的双方用户ID）
     */
    public Map<String, Object> selectSessionContext(@Param("sessionId") Long sessionId);

    /**
     * 按会议链接令牌（ses_room_token）查询面试场次上下文
     */
    public Map<String, Object> selectSessionByRoomToken(@Param("roomToken") String roomToken);

    /**
     * 查询岗位技能标签（用于面试详情展示岗位要求）
     */
    public List<Map<String, Object>> selectPositionSkills(@Param("positionId") Long positionId);

    /**
     * 查询候选人的真实流程记录（用于面试详情展示流程时间线）
     */
    public List<Map<String, Object>> selectCandidateFlowHistory(@Param("candidateId") Long candidateId);

    /**
     * 按用户ID查询候选人档案（用于把聊天对象解析为候选人）
     * companyId 非空时同时限定候选人所属企业，避免跨企业发起面试
     */
    public Map<String, Object> selectTalentByUserId(@Param("userId") Long userId, @Param("companyId") Long companyId);

    /**
     * 确保会议运行时状态记录存在（不存在则按预约时段与大纲题目数初始化）
     */
    public int ensureMeetingState(@Param("sessionId") Long sessionId);

    /**
     * 查询会议运行时状态
     */
    public Map<String, Object> selectMeetingState(@Param("sessionId") Long sessionId);

    /**
     * 写入会前环境检测结果
     */
    public int updateEnvironmentCheck(Map<String, Object> params);

    /**
     * 更新音视频设备状态
     */
    public int updateMediaState(Map<String, Object> params);

    /**
     * 刷新心跳时间
     */
    public int touchHeartbeat(@Param("sessionId") Long sessionId);

    /**
     * 更新 HR 接管状态
     */
    public int updateTakeover(Map<String, Object> params);

    /**
     * 已完成题目数 +1
     */
    public int incrementAnswered(@Param("sessionId") Long sessionId);

    /**
     * 查询下一个对话序号
     */
    public Integer selectNextDialogueOrder(@Param("sessionId") Long sessionId);

    /**
     * 锁定场次行，用于串行化同一场次的实时字幕序号
     */
    public Long lockSessionForUpdate(@Param("sessionId") Long sessionId);

    /**
     * 新增一条对话 / 字幕记录
     */
    public int insertDialogue(Map<String, Object> params);

    /**
     * 增量拉取字幕（面试对话记录）
     */
    public List<Map<String, Object>> selectCaptions(Map<String, Object> params);

    /**
     * 拉取第 N 个面试大纲主题（作为当前题目）
     */
    public Map<String, Object> selectOutlineAt(Map<String, Object> params);

    /**
     * 增量拉取提词器建议
     */
    public List<Map<String, Object>> selectCopilot(Map<String, Object> params);

    /**
     * 查询单条提词器建议（用于权限与状态校验）
     */
    public Map<String, Object> selectCopilotById(@Param("id") Long id);

    /**
     * 处理（采纳 / 编辑 / 忽略）提词器建议
     */
    public int handleCopilot(Map<String, Object> params);

    /**
     * 写入候选人录制知情同意
     */
    public int updateConsent(Map<String, Object> params);

    /**
     * 查询岗位所属企业ID（发起面试时校验岗位归属）
     */
    public Long selectPositionCompanyId(@Param("positionId") Long positionId);

    /**
     * 新增面试预约记录（HR 发起视频面试时即时创建），回填 apt_id
     */
    public int insertAppointment(Map<String, Object> params);

    /**
     * 新增面试场次（关联预约记录），回填 ses_id
     */
    public int insertSession(Map<String, Object> params);

    /**
     * 为已有场次补写房间号与房间令牌
     */
    public int updateSessionRoomToken(Map<String, Object> params);

    /**
     * 把候选人此前尚未结束的场次置为异常终止（每次发起面试都新建场次前调用）
     * companyId 限定只处理本企业岗位上的场次，避免影响其他企业的面试
     */
    public int abortActiveSessionsByCandidate(@Param("candidateId") Long candidateId, @Param("companyId") Long companyId);

    /**
     * 取消候选人本企业下仍处于待面试的预约（重新发起面试时清理旧预约，避免日历残留）
     */
    public int cancelPendingAppointments(@Param("candidateId") Long candidateId, @Param("companyId") Long companyId);

    /**
     * 发起面试后把候选人流程状态推进为「面试中」(2)
     */
    public int markCandidateInterviewing(@Param("candidateId") Long candidateId, @Param("companyId") Long companyId);

    /**
     * 候选人准备就绪，进入面试
     */
    public int startSession(@Param("sessionId") Long sessionId);

    /**
     * 正常结束面试
     */
    public int finishSession(Map<String, Object> params);

    /**
     * 异常终止面试
     */
    public int abortSession(@Param("sessionId") Long sessionId);

    /**
     * 查询面试结果（时长、完成题目数、报告是否生成）
     */
    public Map<String, Object> selectSessionResult(@Param("sessionId") Long sessionId);

    /**
     * 录制文件列表（企业范围内，一场面试可多次录制各为一条）
     */
    public List<Map<String, Object>> selectRecordingList(Map<String, Object> params);

    /**
     * 企业录制总时长（秒）与真实字节数之和，用于统计存储占用
     */
    public Map<String, Object> selectRecordingStorageTotal(@Param("companyId") Long companyId);

    /**
     * 查询场次当前进行中的录制记录（用于重复点击时的复用判断）
     */
    public Map<String, Object> selectActiveRecording(@Param("sessionId") Long sessionId);

    /**
     * 查询场次下一次录制序号（场次内第几次录制）
     */
    public Integer selectNextRecordingSeq(@Param("sessionId") Long sessionId);

    /**
     * 新增录制记录，回填 recordingId
     */
    public int insertRecording(Map<String, Object> params);

    /**
     * 回写录制任务ID（LiveKit Egress）
     */
    public int updateRecordingEgressId(Map<String, Object> params);

    /**
     * 停止录制时的兜底回写：状态置为已完成，时长按录制起止墙钟时间计算
     */
    public int finishRecordingByRecordingId(Map<String, Object> params);

    /**
     * Egress 结束后按任务ID回写状态 / 时长 / 字节数 / 文件地址
     */
    public int finishRecordingByEgressId(Map<String, Object> params);

    /**
     * 场次异常终止时，把仍在进行的录制标记为异常终止
     */
    public int abortRecordingBySession(@Param("sessionId") Long sessionId);

    /**
     * 录制访问校验所需上下文（企业、候选人、面试官、访问级别、文件地址）
     */
    public Map<String, Object> selectRecordingAccessContext(@Param("recordingId") Long recordingId);

    /**
     * 回放详情（按录制记录ID）
     */
    public Map<String, Object> selectRecordingDetail(@Param("recordingId") Long recordingId);

    /**
     * 回放时间轴（面试对话记录，含相对录制起点的秒数，用于章节打点与问答记录）
     */
    public List<Map<String, Object>> selectRecordingTimeline(Map<String, Object> params);

    /**
     * 更新录制访问授权（按录制记录ID）
     */
    public int updateRecordingAccess(Map<String, Object> params);

    /**
     * 查询存储策略（优先企业级，其次全局默认）
     */
    public Map<String, Object> selectStoragePolicy(@Param("companyId") Long companyId);

    /**
     * 保存企业存储策略
     */
    public int upsertStoragePolicy(Map<String, Object> params);

    /**
     * 查询候选人在本企业投递过的岗位（用于 HR 发起面试时选择岗位），含该岗位流程的当前阶段
     */
    public List<Map<String, Object>> selectCandidatePositionsByPeer(Map<String, Object> params);

    /**
     * 查询岗位流程模板的全部阶段（发起面试时选择阶段、按阶段带出默认面试方式与时长）
     */
    public List<Map<String, Object>> selectStagesByPosition(Map<String, Object> params);

    /**
     * 写入 / 更新某个参与者的会前检测与就绪状态（按场次 + 用户唯一）
     */
    public int upsertParticipantState(Map<String, Object> params);

    /**
     * 查询场次下全部参与者的会前状态（用于等候室展示双方）
     */
    public List<Map<String, Object>> selectParticipantStates(@Param("sessionId") Long sessionId);
    /**
     * 写入 / 更新场次面试官关联（多面试官）
     */
    public int insertSessionInterviewer(Map<String, Object> params);

    /**
     * 查询场次全部被指派面试官（主面试官优先）
     */
    public List<Map<String, Object>> selectSessionInterviewers(@Param("sessionId") Long sessionId);

    /**
     * 查询某用户收到的面试邀约通知（消息中心「面试预约通知」系统会话）
     */
    public List<Map<String, Object>> selectInterviewerNotices(@Param("userId") Long userId);

    /**
     * 更新某用户在某场次的面试邀约接受状态（0-待确认，1-已接受，2-已拒绝）
     */
    public int updateInterviewerAcceptStatus(@Param("sessionId") Long sessionId, @Param("userId") Long userId,
            @Param("acceptStatus") Integer acceptStatus);

    /**
     * 查询场次主面试官用户ID（无则返回 null）
     */
    public Long selectPrimaryInterviewerId(@Param("sessionId") Long sessionId);

    /**
     * 清除场次内全部主面试官标记（用于主面试官移交）
     */
    public int clearSessionInterviewerPrimary(@Param("sessionId") Long sessionId);

    /**
     * 标记面试官已加入会议
     */
    public int markSessionInterviewerJoined(Map<String, Object> params);

    /**
     * 把场次主面试官同步为该用户（ses_interviewer_id 兼容旧逻辑）
     */
    public int updateSessionPrimaryInterviewer(@Param("sessionId") Long sessionId, @Param("userId") Long userId);

    /**
     * 查询本企业全部在职用户（HR 发起面试时选择面试官）
     */
    public List<Map<String, Object>> selectCompanyEmployees(Map<String, Object> params);
}
