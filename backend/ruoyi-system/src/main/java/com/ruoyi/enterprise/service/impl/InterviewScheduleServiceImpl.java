package com.ruoyi.enterprise.service.impl;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.InterviewScheduleMapper;
import com.ruoyi.enterprise.service.IInterviewScheduleService;

/**
 * 企业端 - 智能预约调度服务实现
 *
 * <p>依据《业务功能分析》：</p>
 * <ul>
 *   <li>UC-07：发起邀约时占用面试官时段（防止超售），创建预约记录并生成会议链接</li>
 *   <li>UC-08：返回面试官忙闲时段，供时间窗口匹配算法计算最优建议时段</li>
 *   <li>UC-09：改期时原时段自动释放并回退至可用池，新时段占用</li>
 * </ul>
 *
 * @author enterprise
 */
@Service
public class InterviewScheduleServiceImpl implements IInterviewScheduleService
{
    /** 时段状态（DB 设计文档 §3.4）：0-已占用，1-可用 */
    private static final int SLOT_OCCUPIED = 0;
    private static final int SLOT_AVAILABLE = 1;

    /** 预约状态（DB 设计文档 §3.4）：0-待确认，1-已确认，2-已取消，3-已完成 */
    private static final int APT_PENDING = 0;

    private static final DateTimeFormatter[] TIME_FORMATS = {
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"),
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
    };

    @Autowired
    private InterviewScheduleMapper scheduleMapper;

    @Override
    public List<Map<String, Object>> listAppointments(Long userId, Integer status, String from,
            String to, Integer pageNum, Integer pageSize)
    {
        PageUtils.startPage(pageNum, pageSize);
        return scheduleMapper.selectAppointments(status, from, to);
    }

    @Override
    public Map<String, Object> invite(Long userId, Long candidateId, Long positionId,
            Long interviewerId, String startTime, Integer durationMin)
    {
        if (candidateId == null || positionId == null || interviewerId == null || startTime == null)
        {
            throw new ServiceException("候选人/岗位/面试官/开始时间不能为空");
        }
        LocalDateTime start = parseTime(startTime);
        LocalDateTime end = start.plusMinutes(durationMin == null ? 45 : durationMin);

        // 冲突检测（UC-08）：与已占用时段重叠则拒绝
        List<Map<String, Object>> conflicts = scheduleMapper.selectOverlapOccupied(
                interviewerId, format(start), format(end));
        if (!conflicts.isEmpty())
        {
            throw new ServiceException("该时段与面试官已有安排冲突，请更换时间");
        }
        // 占用/创建时段（UC-07 步骤5-6：原子性锁定防止超售）
        Long slotId = scheduleMapper.selectAvailableSlot(interviewerId, format(start), format(end));
        if (slotId != null)
        {
            scheduleMapper.updateSlotStatus(slotId, SLOT_OCCUPIED);
        }
        else
        {
            scheduleMapper.insertSlot(interviewerId, positionId, format(start), format(end), SLOT_OCCUPIED);
            slotId = scheduleMapper.selectLastInsertSlot(interviewerId, format(start));
        }
        // UC-07 步骤7-8：创建预约记录 + 专属会议链接
        scheduleMapper.insertAppointment(candidateId, positionId, interviewerId, slotId,
                format(start), format(end), buildMeetingUrl());
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("appointmentId", scheduleMapper.selectLastAppointment(candidateId));
        result.put("slotId", slotId);
        result.put("startTime", format(start));
        result.put("endTime", format(end));
        result.put("meetingUrl", buildMeetingUrl());
        result.put("status", APT_PENDING);
        result.put("message", "邀约已创建，等待候选人确认");
        return result;
    }

    @Override
    public List<Map<String, Object>> listInterviewerSlots(Long userId, Long interviewerId,
            String from, String to)
    {
        if (interviewerId == null)
        {
            throw new ServiceException("面试官ID不能为空");
        }
        return scheduleMapper.selectSlots(interviewerId, from, to);
    }

    @Override
    public Map<String, Object> reschedule(Long userId, Long appointmentId, String newStartTime)
    {
        if (newStartTime == null)
        {
            throw new ServiceException("新时段不能为空");
        }
        Map<String, Object> appointment = scheduleMapper.selectAppointmentById(appointmentId);
        if (appointment == null)
        {
            throw new ServiceException("预约记录不存在");
        }
        Long interviewerId = Long.valueOf(String.valueOf(appointment.get("interviewerId")));
        int durationMin = 45;
        LocalDateTime start = parseTime(newStartTime);
        LocalDateTime end = start.plusMinutes(durationMin);

        // 新时段冲突检测
        List<Map<String, Object>> conflicts = scheduleMapper.selectOverlapOccupied(
                interviewerId, format(start), format(end));
        if (!conflicts.isEmpty())
        {
            throw new ServiceException("新时段与面试官已有安排冲突，请更换时间");
        }
        // UC-09：原时段自动释放并回退至可用池
        Object oldSlot = appointment.get("slotId");
        if (oldSlot != null)
        {
            scheduleMapper.updateSlotStatus(Long.valueOf(String.valueOf(oldSlot)), SLOT_AVAILABLE);
        }
        // 新时段占用
        Long newSlotId = scheduleMapper.selectAvailableSlot(interviewerId, format(start), format(end));
        if (newSlotId != null)
        {
            scheduleMapper.updateSlotStatus(newSlotId, SLOT_OCCUPIED);
        }
        else
        {
            scheduleMapper.insertSlot(interviewerId,
                    Long.valueOf(String.valueOf(appointment.get("positionId"))),
                    format(start), format(end), SLOT_OCCUPIED);
            newSlotId = scheduleMapper.selectLastInsertSlot(interviewerId, format(start));
        }
        scheduleMapper.updateAppointmentTime(appointmentId, newSlotId, format(start), format(end));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("appointmentId", appointmentId);
        result.put("oldSlotReleased", oldSlot != null);
        result.put("newSlotId", newSlotId);
        result.put("newStartTime", format(start));
        result.put("message", "改期成功，原时段已释放回退可用池");
        return result;
    }

    @Override
    public Map<String, Object> remind(Long userId, Long appointmentId)
    {
        Map<String, Object> appointment = scheduleMapper.selectAppointmentById(appointmentId);
        if (appointment == null)
        {
            throw new ServiceException("预约记录不存在");
        }
        // UC-07 步骤11：向候选人发送提醒（写入系统消息，消息类型枚举口径 P7 与通知模块对齐）
        scheduleMapper.insertReminderMessage(
                Long.valueOf(String.valueOf(appointment.get("candidateUserId"))),
                "面试提醒",
                "您预约的「" + appointment.get("positionTitle") + "」面试即将开始（"
                        + appointment.get("startTime") + "），会议链接："
                        + appointment.get("meetingUrl"));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("appointmentId", appointmentId);
        result.put("message", "提醒已发送");
        return result;
    }

    /** 解析时间字符串（兼容秒/分两种格式） */
    private LocalDateTime parseTime(String text)
    {
        for (DateTimeFormatter format : TIME_FORMATS)
        {
            try
            {
                return LocalDateTime.parse(text.trim(), format);
            }
            catch (Exception ignore)
            {
                // 尝试下一个格式
            }
        }
        throw new ServiceException("时间格式不正确，应为 yyyy-MM-dd HH:mm");
    }

    private String format(LocalDateTime time)
    {
        return time.format(TIME_FORMATS[0]);
    }

    /** 模拟生成专属会议链接（P7 对接视频会议 API 后替换） */
    private String buildMeetingUrl()
    {
        return "https://meeting.example.com/" + System.currentTimeMillis() % 1000000;
    }
}
