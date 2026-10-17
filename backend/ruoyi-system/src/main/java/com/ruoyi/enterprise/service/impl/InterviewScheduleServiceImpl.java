package com.ruoyi.enterprise.service.impl;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Isolation;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.mapper.InterviewScheduleMapper;
import com.ruoyi.enterprise.service.IInterviewScheduleService;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;

/** 企业端阶段邀约与改期。所有写入在锁定候选人、面试官后进行，冲突时整笔回滚。 */
@Service
public class InterviewScheduleServiceImpl implements IInterviewScheduleService
{
    private static final DateTimeFormatter FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    @Autowired private InterviewScheduleMapper scheduleMapper;
    @Autowired private DashboardMapper dashboardMapper;
    @Autowired private EnterpriseJobMapper jobMapper;

    private Long company(Long userId)
    {
        Long id = dashboardMapper.selectCompanyIdByUser(userId);
        if (id == null && SecurityUtils.isAdmin(userId)) id = 1L;
        if (id == null) throw new ServiceException("请先完成企业绑定");
        return id;
    }

    private Long requireJob(Long userId, Long positionId)
    {
        Long companyId = company(userId);
        if (positionId == null || jobMapper.selectJobById(positionId, companyId) == null)
            throw new ServiceException("岗位不存在或无权访问");
        return companyId;
    }

    @Override
    public List<Map<String, Object>> listAppointments(Long userId, Integer status, String from,
            String to, Integer pageNum, Integer pageSize)
    {
        Long companyId = company(userId);
        PageUtils.startPage(pageNum, pageSize);
        return scheduleMapper.selectAppointments(companyId, status, from, to);
    }

    @Override
    public List<Map<String, Object>> candidateAppointments(Long userId, Long candidateId, Long positionId)
    {
        requireJob(userId, positionId);
        return scheduleMapper.selectCandidateAppointments(candidateId, positionId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> invite(Long userId, Long candidateId, Long positionId,
            Long stageId, Long interviewerId, String startTime, Integer durationMin)
    {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("stageId", stageId);
        row.put("interviewerId", interviewerId);
        row.put("startTime", startTime);
        row.put("durationMin", durationMin == null ? 45 : durationMin);
        return create(userId, candidateId, positionId, List.of(row)).get(0);
    }

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public List<Map<String, Object>> inviteStages(Long userId, Long candidateId, Long positionId,
            List<Map<String, Object>> stages)
    {
        if (stages == null || stages.isEmpty() || stages.size() > 50)
            throw new ServiceException("请填写1至50个阶段安排");
        if (stages.stream().anyMatch(row -> row == null || row.get("stageId") == null))
            throw new ServiceException("阶段ID不能为空，请刷新招聘流程");
        return create(userId, candidateId, positionId, stages);
    }

    private List<Map<String, Object>> create(Long userId, Long candidateId, Long positionId,
            List<Map<String, Object>> stages)
    {
        Long companyId = requireJob(userId, positionId);
        if (candidateId == null || scheduleMapper.lockCandidate(candidateId) == null
                || scheduleMapper.countApplication(candidateId, positionId) == 0)
            throw new ServiceException("候选人未投递当前岗位");
        Set<Long> interviewerIds = new TreeSet<>();
        for (Map<String, Object> row : stages) interviewerIds.add(requiredId(row.get("interviewerId")));
        for (Long id : interviewerIds) lockInterviewer(userId, companyId, id);
        List<Map<String, Object>> prepared = new ArrayList<>();
        Set<Long> seen = new HashSet<>();
        for (Map<String, Object> row : stages)
        {
            Long stageId = nullableId(row.get("stageId"));
            Map<String, Object> values = new LinkedHashMap<>();
            if (stageId != null)
            {
                if (!seen.add(stageId)) throw new ServiceException("招聘阶段不能重复");
                Map<String, Object> stage = scheduleMapper.selectStageByIdForPosition(stageId, positionId);
                if (stage == null) throw new ServiceException("招聘阶段已变更，请刷新后重新排期");
                values.putAll(stage);
            }
            else
            {
                values.put("stageId", null);
                values.put("stageName", null);
                values.put("stageType", null);
                values.put("stageOrder", null);
            }
            LocalDateTime start = parseTime(row.get("startTime"));
            int duration = duration(row.get("durationMin"));
            requireFuture(start);
            values.put("candidateId", candidateId);
            values.put("positionId", positionId);
            values.put("interviewerId", requiredId(row.get("interviewerId")));
            values.put("startTime", format(start));
            values.put("endTime", format(start.plusMinutes(duration)));
            prepared.add(values);
        }
        prepared.sort(Comparator.comparingInt(row -> integer(row.get("stageOrder"), 0)));
        List<Map<String, Object>> existing = scheduleMapper.selectCandidateAppointments(candidateId, positionId);
        for (int i = 0; i < prepared.size(); i++)
        {
            Map<String, Object> row = prepared.get(i);
            validateStageOrder(row, existing, null);
            validateStageOrder(row, prepared.subList(0, i), null);
            checkConflicts(row, null, null);
            row.put("meetingUrl", "https://meeting.example.com/" + UUID.randomUUID());
            scheduleMapper.insertSlot(row);
            scheduleMapper.insertAppointment(row);
            row.put("status", 0);
            row.put("message", "邀约已创建，等待候选人确认");
        }
        return prepared;
    }

    private void lockInterviewer(Long userId, Long companyId, Long interviewerId)
    {
        if ((!interviewerId.equals(userId)
                && scheduleMapper.countInterviewerInCompany(interviewerId, companyId) == 0)
                || scheduleMapper.lockInterviewer(interviewerId) == null)
            throw new ServiceException("面试官不属于当前企业或已停用");
    }

    private void validateStageOrder(Map<String, Object> row, List<Map<String, Object>> others, Long excludeId)
    {
        int order = integer(row.get("stageOrder"), 0);
        LocalDateTime start = parseTime(row.get("startTime"));
        LocalDateTime end = parseTime(row.get("endTime"));
        for (Map<String, Object> other : others)
        {
            if (excludeId != null && excludeId.equals(nullableId(other.get("appointmentId")))) continue;
            if (row.get("stageId") != null && row.get("stageId").toString().equals(String.valueOf(other.get("stageId"))))
                throw new ServiceException("该阶段已有面试安排，请编辑已有安排，避免重复邀约");
            int otherOrder = integer(other.get("stageOrder"), 0);
            if (order == 0 || otherOrder == 0) continue;
            if ((otherOrder < order && parseTime(other.get("endTime")).isAfter(start))
                    || (otherOrder > order && parseTime(other.get("startTime")).isBefore(end)))
                throw new ServiceException("时间冲突：各阶段须按招聘流程先后安排");
        }
    }

    private void checkConflicts(Map<String, Object> row, Long excludeId, Long excludeSlot)
    {
        if (!scheduleMapper.selectConflicts(requiredId(row.get("candidateId")),
                requiredId(row.get("interviewerId")), row.get("startTime").toString(),
                row.get("endTime").toString(), excludeId, excludeSlot).isEmpty())
            throw new ServiceException("时间冲突：候选人或面试官在该时段已有安排");
    }

    @Override
    public List<Map<String, Object>> listInterviewerSlots(Long userId, Long interviewerId, String from, String to)
    {
        Long companyId = company(userId);
        if (interviewerId == null || (!interviewerId.equals(userId)
                && scheduleMapper.countInterviewerInCompany(interviewerId, companyId) == 0))
            throw new ServiceException("无权查看该面试官日历");
        return scheduleMapper.selectSlots(interviewerId, from, to);
    }

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> reschedule(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId)
    {
        Map<String, Object> row = scheduleMapper.selectAppointmentById(appointmentId);
        if (row == null) throw new ServiceException("预约记录不存在");
        Long companyId = requireJob(userId, requiredId(row.get("positionId")));
        scheduleMapper.lockCandidate(requiredId(row.get("candidateId")));
        row = scheduleMapper.selectAppointmentById(appointmentId);
        int status = integer(row.get("status"), -1);
        LocalDateTime oldStart = parseTime(row.get("startTime"));
        if ((status != 0 && status != 1) || !oldStart.isAfter(LocalDateTime.now(ZoneOffset.ofHours(8))))
            throw new ServiceException("仅未开始且未取消的面试可以调整");
        Long oldInterviewer = requiredId(row.get("interviewerId"));
        Long nextInterviewer = interviewerId == null ? oldInterviewer : interviewerId;
        Set<Long> ids = new TreeSet<>(List.of(oldInterviewer, nextInterviewer));
        for (Long id : ids) lockInterviewer(userId, companyId, id);
        Long oldSlot = nullableId(row.get("slotId"));
        long originalDuration = java.time.Duration.between(oldStart, parseTime(row.get("endTime"))).toMinutes();
        int minutes = duration(durationMin == null ? originalDuration : durationMin);
        LocalDateTime start = parseTime(newStartTime);
        requireFuture(start);
        row.put("interviewerId", nextInterviewer);
        row.put("startTime", format(start));
        row.put("endTime", format(start.plusMinutes(minutes)));
        validateStageOrder(row, scheduleMapper.selectCandidateAppointments(
                requiredId(row.get("candidateId")), requiredId(row.get("positionId"))), appointmentId);
        checkConflicts(row, appointmentId, oldSlot);
        scheduleMapper.insertSlot(row);
        scheduleMapper.updateAppointmentTime(row);
        if (oldSlot != null) scheduleMapper.updateSlotStatus(oldSlot, 1);
        row.put("status", 0);
        row.put("newStartTime", format(start));
        row.put("newSlotId", row.get("slotId"));
        row.put("oldSlotReleased", oldSlot != null);
        row.put("message", "改期成功，原时段已释放回退可用池");
        return row;
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

    private LocalDateTime parseTime(Object raw)
    {
        try
        {
            return LocalDateTime.parse(String.valueOf(raw).trim().replace(' ', 'T'));
        }
        catch (Exception e) { throw new ServiceException("时间格式不正确，应为 yyyy-MM-dd HH:mm"); }
    }
    private String format(LocalDateTime value) { return value.format(FORMAT); }
    private void requireFuture(LocalDateTime value)
    {
        if (!value.isAfter(LocalDateTime.now(ZoneOffset.ofHours(8))))
            throw new ServiceException("面试时间须晚于当前时间（UTC+8）");
    }
    private int integer(Object value, int fallback)
    {
        try { return Integer.parseInt(String.valueOf(value)); }
        catch (Exception e) { return fallback; }
    }
    private int duration(Object value)
    {
        int minutes = integer(value, -1);
        if (minutes < 1 || minutes > 1440) throw new ServiceException("面试时长须为1至1440分钟");
        return minutes;
    }
    private Long nullableId(Object value)
    {
        if (value == null) return null;
        return requiredId(value);
    }
    private Long requiredId(Object value)
    {
        try
        {
            long id = Long.parseLong(String.valueOf(value));
            if (id > 0) return id;
        }
        catch (Exception ignored) { }
        throw new ServiceException("标识不能为空且须为正整数");
    }
}
