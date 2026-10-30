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
import com.alibaba.fastjson2.JSON;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Isolation;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.mapper.InterviewScheduleMapper;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.IInterviewScheduleService;
import com.ruoyi.enterprise.service.RescheduleMessageService;
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
    @Autowired private ScreeningMapper screeningMapper;
    @Autowired private RescheduleMessageService rescheduleMessages;

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
            String to, Long candidateId, Integer pageNum, Integer pageSize)
    {
        Long companyId = company(userId);
        PageUtils.startPage(pageNum, pageSize);
        return scheduleMapper.selectAppointments(companyId, status, from, to, candidateId);
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
            // 阶段时长以岗位招聘流程配置为准，客户端传入的 durationMin 不作为阶段时长的最终依据；
            // 未绑定阶段的历史单阶段邀约仍沿用客户端时长，保持旧接口兼容。
            int duration = stageId == null
                    ? duration(row.get("durationMin"))
                    : stageConfiguredDuration(values);
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
        // 发起面试后自动把候选人流程状态推进为「面试中」，与候选人管理/面试安排联动
        scheduleMapper.markCandidateInterviewing(candidateId);
        // 同时把该岗位投递状态同步为「已约面」，投递详情/候选人列表立即可见
        screeningMapper.advanceApplicationStatus(positionId, candidateId, 3, List.of(0, 1, 2));
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
        Map<String, Object> result = moveAppointment(userId, appointmentId, newStartTime, durationMin, interviewerId);
        if (rescheduleMessages != null && (!parseTime(result.get("originalStartTime")).equals(parseTime(result.get("startTime")))
                || !parseTime(result.get("originalEndTime")).equals(parseTime(result.get("endTime")))
                || !java.util.Objects.equals(result.get("originalInterviewerId"), result.get("interviewerId"))))
            rescheduleMessages.changed(userId, result);
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> rescheduleSilently(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId)
    {
        return moveAppointment(userId, appointmentId, newStartTime, durationMin, interviewerId);
    }

    private Map<String, Object> moveAppointment(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId)
    {
        Map<String, Object> row = scheduleMapper.selectAppointmentById(appointmentId);
        if (row == null) throw new ServiceException("预约记录不存在");
        Long companyId = requireJob(userId, requiredId(row.get("positionId")));
        scheduleMapper.lockCandidate(requiredId(row.get("candidateId")));
        row = scheduleMapper.selectAppointmentById(appointmentId);
        row.put("originalStartTime", row.get("startTime"));
        row.put("originalEndTime", row.get("endTime"));
        row.put("originalInterviewerId", row.get("interviewerId"));
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

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> updateStatus(Long userId, Long appointmentId, Integer status)
    {
        if (status == null || (status != 1 && status != 2))
            throw new ServiceException("仅支持确认(1)或取消(2)面试安排");
        Map<String, Object> row = scheduleMapper.selectAppointmentById(appointmentId);
        if (row == null) throw new ServiceException("预约记录不存在");
        requireJob(userId, requiredId(row.get("positionId")));
        // 与创建/改期/改期申请审批一致，先锁候选人再锁预约行，串行化取消与并发排期。
        lockCandidateAndAppointment(row);
        int current = integer(row.get("status"), -1);
        if (current == 3) throw new ServiceException("该面试安排已完成，无法变更状态");
        if (status == 1)
        {
            if (current == 2) throw new ServiceException("该面试安排已取消，无法确认");
            confirmOrThrow(appointmentId);
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("appointmentId", appointmentId);
            result.put("status", status);
            result.put("message", "已确认该面试安排");
            return result;
        }
        // 取消：重复取消幂等返回，不重复释放时段、不重复回退状态。
        return cancelAppointment(requiredId(row.get("candidateId")), requiredId(row.get("positionId")),
                appointmentId, row, true);
    }

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> cancelForRelaunch(Long userId, Long appointmentId)
    {
        Map<String, Object> row = scheduleMapper.selectAppointmentById(appointmentId);
        if (row == null) return skippedCancel(appointmentId, "预约记录不存在，已跳过");
        requireJob(userId, requiredId(row.get("positionId")));
        lockCandidateAndAppointment(row);
        // 会议重新发起前的清理：已取消、已完成的预约静默跳过，不阻断会议创建。
        return cancelAppointment(requiredId(row.get("candidateId")), requiredId(row.get("positionId")),
                appointmentId, row, false);
    }

    @Override
    public Map<String, Object> resetRemindStatus(Long userId, Long appointmentId)
    {
        Map<String, Object> row = scheduleMapper.selectAppointmentById(appointmentId);
        if (row == null) throw new ServiceException("预约记录不存在");
        requireJob(userId, requiredId(row.get("positionId")));
        int status = integer(row.get("status"), -1);
        if (status != 0 && status != 1)
            throw new ServiceException("仅未取消且未完成的面试可以重置提醒");
        if (!parseTime(row.get("startTime")).isAfter(LocalDateTime.now(ZoneOffset.ofHours(8))))
            throw new ServiceException("仅未开始的面试可以重置提醒");
        // 只重置已处理(1)的标记，不触碰发送中(2)的认领，也不触发自动发送；
        // 下一次提醒扫描按窗口规则决定是否发送。
        scheduleMapper.resetAppointmentRemindFlag(appointmentId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("appointmentId", appointmentId);
        result.put("message", "提醒状态已重置，将在下次提醒扫描时按窗口规则处理");
        return result;
    }

    /** 候选人行锁 → 预约行锁，与创建/改期/改期申请审批保持同一锁顺序。 */
    private void lockCandidateAndAppointment(Map<String, Object> row)
    {
        if (scheduleMapper.lockCandidate(requiredId(row.get("candidateId"))) == null)
            throw new ServiceException("候选人不存在，无法变更状态");
        scheduleMapper.lockAppointment(requiredId(row.get("appointmentId")));
        Map<String, Object> latest = scheduleMapper.selectAppointmentById(requiredId(row.get("appointmentId")));
        row.putAll(latest);
    }

    /**
     * 取消预约核心业务：状态更新、时段释放、候选人/投递状态恢复，供 HR 取消与会议重新发起共用。
     *
     * @param strict true 时已完成预约抛错（HR 取消入口）；false 时已取消/已完成返回跳过结果（会议清理入口）
     */
    private Map<String, Object> cancelAppointment(Long candidateId, Long positionId,
            Long appointmentId, Map<String, Object> row, boolean strict)
    {
        int current = integer(row.get("status"), -1);
        if (current == 2)
            return strict ? idempotentCancel(candidateId, positionId, appointmentId)
                    : skippedCancel(appointmentId, "该面试安排已取消，已跳过");
        if (current == 3)
        {
            if (strict) throw new ServiceException("该面试安排已完成，无法变更状态");
            return skippedCancel(appointmentId, "该面试安排已完成，已跳过");
        }
        Long interviewerId = nullableId(row.get("interviewerId"));
        if (interviewerId != null) scheduleMapper.lockInterviewer(interviewerId);
        if (scheduleMapper.updateAppointmentStatus(appointmentId, 2) != 1)
        {
            Map<String, Object> latest = scheduleMapper.selectAppointmentById(appointmentId);
            int latestStatus = latest == null ? -1 : integer(latest.get("status"), -1);
            // 并发下已被取消：HR 取消按幂等成功处理，会议清理按跳过处理。
            if (latestStatus == 2)
                return strict ? idempotentCancel(candidateId, positionId, appointmentId)
                        : skippedCancel(appointmentId, "该面试安排已取消，已跳过");
            throw new ServiceException("该面试安排状态已变化，请刷新后重试");
        }
        Long slotId = nullableId(row.get("slotId"));
        boolean slotReleased = false;
        if (slotId != null)
        {
            // 只释放该预约实际关联的时段；改期已换时段时旧时段早已由改期释放。
            scheduleMapper.updateSlotStatus(slotId, 1);
            slotReleased = true;
        }
        int remaining = scheduleMapper.countOtherValidAppointments(candidateId, positionId, appointmentId);
        int[] restored = restoreCandidateAndApplication(candidateId, positionId, appointmentId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("appointmentId", appointmentId);
        result.put("status", 2);
        result.put("message", "已取消该面试安排" + (slotReleased ? "，面试官时段已释放" : ""));
        result.put("slotReleased", slotReleased);
        result.put("remainingAppointments", remaining);
        result.put("candidateStatusRestored", restored[0] == 1);
        result.put("applicationStatusRestored", restored[1] == 1);
        return result;
    }

    /** 重复取消的幂等结果：不重复释放时段、不重复回退状态。 */
    private Map<String, Object> idempotentCancel(Long candidateId, Long positionId, Long appointmentId)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("appointmentId", appointmentId);
        result.put("status", 2);
        result.put("message", "该面试安排此前已取消，无需重复操作");
        result.put("slotReleased", false);
        result.put("candidateStatusRestored", false);
        result.put("applicationStatusRestored", false);
        result.put("remainingAppointments",
                scheduleMapper.countOtherValidAppointments(candidateId, positionId, appointmentId));
        return result;
    }

    /** 会议重新发起清理的跳过结果：历史预约状态已收敛，无需处理。 */
    private Map<String, Object> skippedCancel(Long appointmentId, String reason)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("appointmentId", appointmentId);
        result.put("status", 2);
        result.put("message", reason);
        result.put("slotReleased", false);
        result.put("candidateStatusRestored", false);
        result.put("applicationStatusRestored", false);
        return result;
    }

    /** 条件更新确认状态；影响行数为 0 且并非同值幂等时抛错，避免并发取消后仍返回成功。 */
    private void confirmOrThrow(Long appointmentId)
    {
        if (scheduleMapper.updateAppointmentStatus(appointmentId, 1) != 1
                && integer(scheduleMapper.selectAppointmentById(appointmentId).get("status"), -1) != 1)
            throw new ServiceException("该面试安排状态已变化，请刷新后重试");
    }

    /**
     * 取消预约后按需把候选人/投递状态回退到进入「面试中」之前。
     *
     * <p>投递状态按岗位判定（该岗位无其他有效预约），候选人状态按全岗位判定（跨岗位无有效预约），
     * 防止回退影响其他岗位正在进行的面试。仅当其余条件全部满足才回退，防止把已完成其他阶段
     * 或笔试通过的候选人错误回退：招聘流程实例进行中、该岗位无已完成面试场次、候选人当前为
     * 面试中(2)且投递为已约面(3)、状态日志中最近一次进入 2 的来源为 0/1（笔试态 5/6 等不回退）。
     * 条件更新限定当前状态，不覆盖并发变更；日志缺失时保持现状不猜测。</p>
     */
    private int[] restoreCandidateAndApplication(Long candidateId, Long positionId, Long cancelledAppointmentId)
    {
        int[] restored = {0, 0};
        Integer talStatus = scheduleMapper.selectTalStatus(candidateId);
        if (talStatus == null || talStatus != 2) return restored;
        Integer pinStatus = scheduleMapper.selectProcessInstanceStatus(candidateId, positionId);
        if (pinStatus == null || pinStatus != 0) return restored;
        if (scheduleMapper.countCompletedSessions(candidateId, positionId) > 0) return restored;
        Integer appStatus = scheduleMapper.selectApplicationStatus(candidateId, positionId);
        if (appStatus == null || appStatus != 3) return restored;
        Integer prior = scheduleMapper.selectPriorTalStatus(candidateId);
        if (prior == null || (prior != 0 && prior != 1)) return restored;
        if (scheduleMapper.countValidAppointmentsExcluding(candidateId, cancelledAppointmentId) == 0
                && scheduleMapper.restoreTalStatus(candidateId, prior) == 1)
            restored[0] = 1;
        if (scheduleMapper.countOtherValidAppointments(candidateId, positionId, cancelledAppointmentId) == 0
                && scheduleMapper.restoreApplicationStatus(candidateId, positionId, prior) == 1)
            restored[1] = 1;
        return restored;
    }

    /** 从阶段配置 JSON（psg_interviewer_config_json）读取面试时长，缺失或越界时拒绝排期。 */
    private int stageConfiguredDuration(Map<String, Object> values)
    {
        try
        {
            Object raw = values.get("configJson");
            Map<String, Object> config = raw instanceof Map
                    ? (Map<String, Object>) raw
                    : JSON.parseObject(String.valueOf(raw));
            int minutes = Integer.parseInt(String.valueOf(config.get("duration")));
            if (minutes >= 1 && minutes <= 1440) return minutes;
        }
        catch (Exception ignored) { }
        throw new ServiceException("该阶段未配置面试时长，请先在岗位招聘流程中完善");
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
