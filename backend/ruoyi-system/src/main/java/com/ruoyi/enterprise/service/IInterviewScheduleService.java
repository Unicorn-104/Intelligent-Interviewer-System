package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - 智能预约调度服务层
 *
 * <p>依据《业务功能分析》UC-07/08/09。</p>
 *
 * @author enterprise
 */
public interface IInterviewScheduleService
{
    /**
     * 面试日程列表（UC-07）：预约记录 + 候选人/岗位/面试官信息
     */
    public List<Map<String, Object>> listAppointments(Long userId, Integer status, String from,
            String to, Long candidateId, Integer pageNum, Integer pageSize);

    /**
     * 发起面试邀约（UC-07）：占用面试官时段 + 创建预约记录 + 生成会议链接
     */
    public Map<String, Object> invite(Long userId, Long candidateId, Long positionId,
            Long stageId, Long interviewerId, String startTime, Integer durationMin);

    /**
     * 面试官日历忙闲（UC-08）：可用/已占用时段列表
     */
    public List<Map<String, Object>> listInterviewerSlots(Long userId, Long interviewerId,
            String from, String to);

    /**
     * 面试改期（UC-09）：释放原时段（回退可用池）+ 占用新时段 + 更新预约
     */
    public Map<String, Object> reschedule(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId);

    /** 由改期审批服务在同一事务统一发送审批结果，避免重复通知。 */
    Map<String, Object> rescheduleSilently(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId);

    public List<Map<String, Object>> inviteStages(Long userId, Long candidateId, Long positionId,
            List<Map<String, Object>> stages);

    public List<Map<String, Object>> candidateAppointments(Long userId, Long candidateId, Long positionId);

    /**
     * 面试提醒（UC-07 步骤11）：向候选人发送提醒消息（写入系统消息）
     */
    public Map<String, Object> remind(Long userId, Long appointmentId);

    /**
     * 确认/取消面试安排（UC-07）：1-已确认，2-已取消
     */
    public Map<String, Object> updateStatus(Long userId, Long appointmentId, Integer status);

    /**
     * 重新发起面试前的待面试预约清理（会议模块统一入口）：
     * 与取消共用同一业务逻辑（释放时段、恢复候选人/投递状态）；
     * 已取消、已完成或不存在的预约静默跳过，不抛错，保证会议创建不被历史数据阻断。
     */
    Map<String, Object> cancelForRelaunch(Long userId, Long appointmentId);
}
