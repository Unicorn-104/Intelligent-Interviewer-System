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
     * 按场次ID查询面试场次上下文（含访问校验所需的双方用户ID）
     */
    public Map<String, Object> selectSessionContext(@Param("sessionId") Long sessionId);

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
     * 录制文件列表（企业范围内）
     */
    public List<Map<String, Object>> selectRecordingList(Map<String, Object> params);

    /**
     * 企业录制总时长（秒），用于估算存储占用
     */
    public Long selectRecordingSecondsTotal(@Param("companyId") Long companyId);

    /**
     * 回放详情
     */
    public Map<String, Object> selectRecordingDetail(@Param("sessionId") Long sessionId);

    /**
     * 回放时间轴（面试对话记录，含相对录制起点的秒数，用于章节打点与问答记录）
     */
    public List<Map<String, Object>> selectRecordingTimeline(@Param("sessionId") Long sessionId);

    /**
     * 更新录制访问授权
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
}