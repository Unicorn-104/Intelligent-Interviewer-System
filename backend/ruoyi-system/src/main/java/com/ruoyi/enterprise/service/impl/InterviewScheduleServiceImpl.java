package com.ruoyi.enterprise.service.impl;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
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
import com.ruoyi.common.enums.ApplicationStatus;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.domain.ProcessStageInstance;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.mapper.InterviewScheduleMapper;
import com.ruoyi.enterprise.mapper.RescheduleRequestMapper;
import com.ruoyi.enterprise.service.ApplicationStatusService;
import com.ruoyi.enterprise.service.IInterviewScheduleService;
import com.ruoyi.enterprise.service.ProcessStageInstanceService;
import com.ruoyi.enterprise.service.RescheduleMessageService;
import com.ruoyi.enterprise.service.TalStatusService;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseJobMapper;
import com.ruoyi.system.service.EmailService;

/** 企业端阶段邀约与改期。所有写入在锁定候选人、面试官后进行，冲突时整笔回滚。 */
@Service
public class InterviewScheduleServiceImpl implements IInterviewScheduleService
{
    private static final DateTimeFormatter FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    @Autowired private InterviewScheduleMapper scheduleMapper;
    @Autowired private RescheduleRequestMapper rescheduleRequestMapper;
    @Autowired private DashboardMapper dashboardMapper;
    @Autowired private EnterpriseJobMapper jobMapper;
    @Autowired private RescheduleMessageService rescheduleMessages;
    @Autowired private TalStatusService talStatusService;
    @Autowired private ApplicationStatusService applicationStatusService;
    @Autowired private ApplicationStatusMapper applicationStatusMapper;
    @Autowired private ProcessStageInstanceService stageInstanceService;
    @Autowired(required = false) private EmailService emailService;

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
        List<Map<String, Object>> rows = scheduleMapper.selectAppointments(companyId, status, from, to, candidateId);
        attachInterviewers(rows);
        return rows;
    }

    /** 批量补上本场次的面试官及确认状态（一次查询，避免逐条 N+1）。 */
    private void attachInterviewers(List<Map<String, Object>> rows)
    {
        if (rows == null || rows.isEmpty()) return;
        List<Long> sessionIds = new ArrayList<>();
        List<Long> appointmentIds = new ArrayList<>();
        for (Map<String, Object> row : rows)
        {
            Long sessionId = nullableId(row.get("sessionId"));
            if (sessionId != null && !sessionIds.contains(sessionId)) sessionIds.add(sessionId);
            Long appointmentId = nullableId(row.get("appointmentId"));
            if (appointmentId != null && !appointmentIds.contains(appointmentId)) appointmentIds.add(appointmentId);
        }
        Map<Long, List<Map<String, Object>>> bySession = new LinkedHashMap<>();
        Map<Long, List<Map<String, Object>>> byAppointment = new LinkedHashMap<>();
        if (!sessionIds.isEmpty())
        {
            for (Map<String, Object> item : scheduleMapper.selectInterviewersBySessionIds(sessionIds))
            {
                bySession.computeIfAbsent(requiredId(item.get("sessionId")), k -> new ArrayList<>()).add(item);
            }
        }
        if (!appointmentIds.isEmpty())
        {
            for (Map<String, Object> item : scheduleMapper.selectAppointmentInterviewers(appointmentIds))
            {
                byAppointment.computeIfAbsent(requiredId(item.get("appointmentId")), k -> new ArrayList<>()).add(item);
            }
        }
        for (Map<String, Object> row : rows)
        {
            Long sessionId = nullableId(row.get("sessionId"));
            Long appointmentId = nullableId(row.get("appointmentId"));
            List<Map<String, Object>> interviewers = sessionId == null
                    ? byAppointment.getOrDefault(appointmentId, new ArrayList<>())
                    : bySession.getOrDefault(sessionId, new ArrayList<>());
            // 兼容迁移前创建的预约：无面试官关联表记录时回落到主面试官字段。
            if (interviewers.isEmpty())
            {
                Long legacyId = nullableId(row.get("interviewerId"));
                if (legacyId != null)
                {
                    Map<String, Object> legacy = new LinkedHashMap<>();
                    legacy.put("userId", legacyId);
                    legacy.put("userName", row.get("interviewerName"));
                    legacy.put("isPrimary", 1);
                    interviewers = new ArrayList<>(List.of(legacy));
                }
            }
            row.put("interviewers", interviewers);
            List<Long> ids = new ArrayList<>();
            for (Map<String, Object> interviewer : interviewers)
            {
                Long id = nullableId(interviewer.get("userId"));
                if (id != null) ids.add(id);
            }
            row.put("interviewerIds", ids);
        }
    }

    /** 改期后通知全部被指派面试官（系统消息 + 邮件，尽力而为）。 */
    private void notifyInterviewerReschedule(Map<String, Object> row, Long organizerId)
    {
        Long appointmentId = nullableId(row.get("appointmentId"));
        if (appointmentId == null) return;
        String stage = row.get("stageName") == null ? "面试" : String.valueOf(row.get("stageName"));
        String content = "面试安排已调整：「" + stage + "」，候选人："
                + row.get("candidateName") + "，新时间：" + row.get("startTime") + "。";
        for (Map<String, Object> interviewer : scheduleMapper.selectAppointmentInterviewers(List.of(appointmentId)))
        {
            Long interviewerId = nullableId(interviewer.get("userId"));
            if (interviewerId == null || interviewerId.equals(organizerId)) continue;
            scheduleMapper.insertReminderMessage(interviewerId, stage + "改期通知", content);
            String email = interviewer.get("email") == null ? "" : String.valueOf(interviewer.get("email")).trim();
            if (email.isEmpty() || emailService == null) continue;
            String name = interviewer.get("userName") == null ? "面试官" : String.valueOf(interviewer.get("userName"));
            try
            {
                emailService.sendSimpleMail(email, "【面试改期】" + stage,
                        "您好，" + name + "：\n\n" + content + "\n请按新时间参加。");
            }
            catch (Exception ignored)
            {
            }
        }
    }

    /** 向非发起人的被指派面试官写入系统消息，并尽力发送安排邮件。 */
    private void notifyInterviewerAssignment(Map<String, Object> row, String stage,
            String content, Long organizerId)
    {
        Object raw = row.get("interviewers");
        if (!(raw instanceof List)) return;
        for (Object item : (List<?>) raw)
        {
            if (!(item instanceof Map)) continue;
            Map<?, ?> interviewer = (Map<?, ?>) item;
            Long interviewerId = nullableId(interviewer.get("userId"));
            if (interviewerId == null || interviewerId.equals(organizerId)) continue;
            scheduleMapper.insertReminderMessage(interviewerId, stage + "安排通知", content);
            String email = interviewer.get("email") == null ? "" : String.valueOf(interviewer.get("email")).trim();
            if (email.isEmpty() || emailService == null) continue;
            String name = interviewer.get("userName") == null ? "面试官" : String.valueOf(interviewer.get("userName"));
            String subject = "【面试安排】" + stage;
            String mail = "您好，" + name + "：\n\n"
                    + "您已被安排为「" + stage + "」面试官。\n"
                    + "候选人：" + row.get("candidateName") + "\n"
                    + "应聘岗位：" + row.get("positionTitle") + "\n"
                    + "面试时间：" + row.get("startTime") + "\n\n"
                    + "面试开始后，请在企业端消息中点击「进入面试」卡片进入会议。\n"
                    + "请提前确认时间并准时参加。";
            try
            {
                emailService.sendSimpleMail(email, subject, mail);
            }
            catch (Exception ignored)
            {
                // 邮件失败不影响邀约主流程，系统消息仍可触达。
            }
        }
    }

    @Override
    public List<Map<String, Object>> candidateAppointments(Long userId, Long candidateId, Long positionId)
    {
        requireJob(userId, positionId);
        List<Map<String, Object>> rows = scheduleMapper.selectCandidateAppointments(candidateId, positionId);
        attachInterviewers(rows);
        return rows;
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
        // 已进入终态（已录用/未录用）的投递不允许再安排面试
        if (scheduleMapper.countSchedulableApplication(candidateId, positionId) == 0)
            throw new ServiceException("该投递已进入终态（已录用或未录用），无法安排面试");
        Set<Long> interviewerIds = new TreeSet<>();
        for (Map<String, Object> row : stages)
            for (Long id : stageInterviewers(row)) interviewerIds.add(id);
        for (Long id : interviewerIds) lockInterviewer(userId, companyId, id);
        List<Map<String, Object>> prepared = new ArrayList<>();
        Set<Long> seen = new HashSet<>();
        for (Map<String, Object> row : stages)
        {
            Long stageId = nullableId(row.get("stageId"));
            List<Long> rowInterviewers = stageInterviewers(row);
            Map<String, Object> values = new LinkedHashMap<>();
            if (stageId != null)
            {
                if (!seen.add(stageId)) throw new ServiceException("招聘阶段不能重复");
                Map<String, Object> stage = scheduleMapper.selectStageByIdForCandidate(
                        stageId, candidateId, positionId);
                if (stage == null) throw new ServiceException("招聘阶段已变更，请刷新后重新排期");
                if (integer(stage.get("stageType"), 0) == ProcessStageInstance.TYPE_EXAM)
                    throw new ServiceException("在线笔试由笔试安排统一管理，不能创建面试预约");
                values.putAll(stage);
                // 岗位流程中先有笔试阶段时，必须笔试节点通过才能安排后续面试（当前环节由真实节点计算）
                if (scheduleMapper.countRequiredExamStagesBeforeCandidate(candidateId, positionId,
                        integer(stage.get("stageOrder"), 0)) > 0
                        && !hasPassedRequiredExamNodes(candidateId, positionId,
                                integer(stage.get("stageOrder"), 0)))
                {
                    throw new ServiceException("该岗位流程中笔试阶段尚未通过，暂不能安排后续面试");
                }
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
            values.put("interviewerId", rowInterviewers.get(0));
            values.put("interviewerIds", rowInterviewers);
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
            Map<String, Object> detail = scheduleMapper.selectAppointmentById(requiredId(row.get("appointmentId")));
            if (detail != null)
            {
                row.put("candidateName", detail.get("candidateName"));
                row.put("positionTitle", detail.get("positionTitle"));
            }
            List<Long> rowInterviewers = castIds(row.get("interviewerIds"));
            for (int index = 0; index < rowInterviewers.size(); index++)
            {
                scheduleMapper.insertAppointmentInterviewer(
                        requiredId(row.get("appointmentId")), rowInterviewers.get(index),
                        index == 0 ? 1 : 0);
            }
            // 每轮面试建独立节点（按 apt_id 幂等），节点结果不等同投递结果
            createInterviewNode(candidateId, positionId, row, userId);
            row.put("status", 0);
            row.put("message", "邀约已创建，等待候选人确认");
        }
        attachInterviewers(prepared);
        for (Map<String, Object> row : prepared)
        {
            String stage = row.get("stageName") == null ? "面试" : String.valueOf(row.get("stageName"));
            String content = "您已被安排为「" + stage + "」面试官，候选人："
                    + row.get("candidateName") + "，时间：" + row.get("startTime")
                    + "。开始面试后可在消息中直接进入会议。";
            notifyInterviewerAssignment(row, stage, content, userId);
        }
        // 发起面试后自动把候选人流程状态推进为「面试中」，已淘汰/已录用的终态不会回退（tal_status 独立维度）
        // 能否安排面试只看「所选岗位」的投递状态（上方 countSchedulableApplication），
        // 候选人全局人才状态已在其他岗位进入终态时不再阻断本岗位面试，仅不再回退推进
        talStatusService.change(candidateId, TalStatusService.TAL_INTERVIEWING,
                List.of(TalStatusService.TAL_NEW, TalStatusService.TAL_SCREENED, TalStatusService.TAL_INTERVIEWING,
                        TalStatusService.TAL_EXAM_PASSED),
                positionId, null, "安排面试", userId);
        // HR 安排第一场正式面试：若投递仍为「已投递(0)」，经状态机进入「招聘中(1)」；
        // 多轮/改期/补面/重新面试全程保持招聘中，不写旧的「已约面(3)」。
        Long appId = applicationStatusMapper.selectAppId(candidateId, positionId);
        if (appId != null && integer(appStatusOf(appId), -1) == ApplicationStatus.APPLIED.getCode())
            applicationStatusService.startRecruitment(appId, userId);
        return prepared;
    }

    private void lockInterviewer(Long userId, Long companyId, Long interviewerId)
    {
        if ((!interviewerId.equals(userId)
                && scheduleMapper.countInterviewerInCompany(interviewerId, companyId) == 0)
                || scheduleMapper.lockInterviewer(interviewerId) == null)
            throw new ServiceException("面试官不属于当前企业或已停用");
    }

    /** 阶段面试官列表：优先 interviewerIds，兼容旧版单 interviewerId。 */
    private List<Long> stageInterviewers(Map<String, Object> row)
    {
        List<Long> ids = castIds(row.get("interviewerIds"));
        if (ids.isEmpty())
        {
            Long single = nullableId(row.get("interviewerId"));
            if (single != null) ids.add(single);
        }
        if (ids.isEmpty()) throw new ServiceException("请选择至少一位面试官");
        return ids;
    }

    private List<Long> castIds(Object raw)
    {
        LinkedHashSet<Long> ids = new LinkedHashSet<>();
        if (raw instanceof Iterable<?> values)
        {
            for (Object value : values)
            {
                Long id = nullableId(value);
                if (id != null) ids.add(id);
            }
        }
        else
        {
            Long id = nullableId(raw);
            if (id != null) ids.add(id);
        }
        return new ArrayList<>(ids);
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
        for (Long interviewerId : stageInterviewers(row))
        {
            if (!scheduleMapper.selectConflicts(requiredId(row.get("candidateId")),
                    interviewerId, row.get("startTime").toString(),
                    row.get("endTime").toString(), excludeId, excludeSlot).isEmpty())
                throw new ServiceException("时间冲突：候选人或面试官在该时段已有安排");
        }
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
        return reschedule(userId, appointmentId, newStartTime, durationMin, interviewerId, null);
    }

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> reschedule(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId, List<Long> interviewerIds)
    {
        Map<String, Object> result = moveAppointment(userId, appointmentId, newStartTime, durationMin,
                interviewerId, interviewerIds);
        if (!parseTime(result.get("originalStartTime")).equals(parseTime(result.get("startTime")))
                || !parseTime(result.get("originalEndTime")).equals(parseTime(result.get("endTime")))
                || !java.util.Objects.equals(result.get("originalInterviewerId"), result.get("interviewerId")))
        {
            Map<String, Object> history = new java.util.LinkedHashMap<>();
            history.put("appointmentId", result.get("appointmentId"));
            history.put("companyId", result.get("companyId"));
            history.put("candidateId", result.get("candidateId"));
            history.put("requesterId", userId);
            history.put("originalStartTime", result.get("originalStartTime"));
            history.put("originalEndTime", result.get("originalEndTime"));
            history.put("originalInterviewerId", result.get("originalInterviewerId"));
            history.put("newStartTime", result.get("startTime"));
            history.put("newEndTime", result.get("endTime"));
            history.put("reason", "企业发起改期");
            history.put("reviewerId", userId);
            history.put("reviewNote", "企业直接调整面试安排");
            if (rescheduleRequestMapper != null) {
                rescheduleRequestMapper.insertEnterpriseRecord(history);
            }
            if (rescheduleMessages != null) rescheduleMessages.changed(userId, result);
            notifyInterviewerReschedule(result, userId);
        }
        return result;
    }

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> rescheduleSilently(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId)
    {
        return rescheduleSilently(userId, appointmentId, newStartTime, durationMin, interviewerId, null);
    }

    @Override
    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> rescheduleSilently(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId, List<Long> interviewerIds)
    {
        return moveAppointment(userId, appointmentId, newStartTime, durationMin, interviewerId, interviewerIds);
    }

    private Map<String, Object> moveAppointment(Long userId, Long appointmentId, String newStartTime,
            Integer durationMin, Long interviewerId, List<Long> interviewerIds)
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
        List<Long> currentIds = new ArrayList<>();
        for (Map<String, Object> item : scheduleMapper.selectAppointmentInterviewers(List.of(appointmentId)))
        {
            Long id = nullableId(item.get("userId"));
            if (id != null) currentIds.add(id);
        }
        if (currentIds.isEmpty()) currentIds.add(oldInterviewer);
        List<Long> nextIds = castIds(interviewerIds);
        if (nextIds.isEmpty())
        {
            if (interviewerId != null && !currentIds.contains(interviewerId))
                nextIds = new ArrayList<>(List.of(interviewerId));
            else
                nextIds = new ArrayList<>(currentIds);
        }
        Long nextInterviewer = nextIds.get(0);
        Set<Long> ids = new TreeSet<>(currentIds);
        ids.addAll(nextIds);
        for (Long id : ids) lockInterviewer(userId, companyId, id);
        Long oldSlot = nullableId(row.get("slotId"));
        long originalDuration = java.time.Duration.between(oldStart, parseTime(row.get("endTime"))).toMinutes();
        int minutes = duration(durationMin == null ? originalDuration : durationMin);
        LocalDateTime start = parseTime(newStartTime);
        requireFuture(start);
        row.put("interviewerId", nextInterviewer);
        row.put("interviewerIds", nextIds);
        row.put("startTime", format(start));
        row.put("endTime", format(start.plusMinutes(minutes)));
        validateStageOrder(row, scheduleMapper.selectCandidateAppointments(
                requiredId(row.get("candidateId")), requiredId(row.get("positionId"))), appointmentId);
        checkConflicts(row, appointmentId, oldSlot);
        scheduleMapper.insertSlot(row);
        scheduleMapper.updateAppointmentTime(row);
        if (oldSlot != null) scheduleMapper.updateSlotStatus(oldSlot, 1);
        scheduleMapper.deleteAppointmentInterviewers(appointmentId);
        for (int index = 0; index < nextIds.size(); index++)
        {
            scheduleMapper.insertAppointmentInterviewer(appointmentId, nextIds.get(index),
                    index == 0 ? 1 : 0);
        }
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
            // 确认面试：节点 待开始→进行中（幂等，节点推进不回写投递状态）
            startInterviewNode(row);
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
        // 取消只释放面试官时段与节点状态，不自动终止投递、不回退旧初筛态（投递状态一律经状态机）
        cancelInterviewNode(candidateId, positionId, row);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("appointmentId", appointmentId);
        result.put("status", 2);
        result.put("message", "已取消该面试安排" + (slotReleased ? "，面试官时段已释放" : ""));
        result.put("slotReleased", slotReleased);
        result.put("remainingAppointments", remaining);
        result.put("candidateStatusRestored", false);
        result.put("applicationStatusRestored", false);
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

    /** 读取投递当前 app_status（只读判断，不做变更）；无投递返回 null。 */
    private Integer appStatusOf(Long appId)
    {
        if (appId == null) return null;
        Map<String, Object> app = applicationStatusMapper.selectApplicationById(appId);
        Object v = app == null ? null : app.get("status");
        if (v == null) return null;
        try { return Integer.parseInt(String.valueOf(v)); }
        catch (Exception e) { return null; }
    }

    /** 读取招聘流程实例ID（节点挂载点）；缺失则无法建节点，返回 null。 */
    private Long instanceIdOf(Long appId)
    {
        if (appId == null) return null;
        Map<String, Object> app = applicationStatusMapper.selectApplicationById(appId);
        Object inst = app == null ? null : app.get("instanceId");
        return inst == null ? null : Long.valueOf(String.valueOf(inst));
    }

    /** 由预约行推断面试节点类型：psg_type=2 记 AI 面试，其余记 HR 综合面试。 */
    private int nodeTypeOf(Map<String, Object> row)
    {
        return integer(row.get("stageType"), 0) == ProcessStageInstance.TYPE_AI_INTERVIEW
                ? ProcessStageInstance.TYPE_AI_INTERVIEW
                : ProcessStageInstance.TYPE_HR_INTERVIEW;
    }

    private String nodeNameOf(Map<String, Object> row)
    {
        return row.get("stageName") == null ? "面试" : String.valueOf(row.get("stageName"));
    }

    /** 为一场面试建独立节点（按 apt_id 幂等），节点结果不等同投递结果。 */
    private void createInterviewNode(Long candidateId, Long positionId, Map<String, Object> row, Long operatorId)
    {
        Long instanceId = instanceIdOf(applicationStatusMapper.selectAppId(candidateId, positionId));
        if (instanceId == null) return;
        stageInstanceService.getOrCreate(instanceId, nullableId(row.get("stageId")), nodeTypeOf(row),
                nodeNameOf(row), requiredId(row.get("appointmentId")), operatorId);
    }

    /** 确认面试：节点 待开始→进行中（幂等）。 */
    private void startInterviewNode(Map<String, Object> row)
    {
        Long instanceId = instanceIdOf(applicationStatusMapper.selectAppId(
                requiredId(row.get("candidateId")), requiredId(row.get("positionId"))));
        if (instanceId == null) return;
        ProcessStageInstance node = stageInstanceService.getOrCreate(instanceId,
                nullableId(row.get("stageId")), nodeTypeOf(row), nodeNameOf(row),
                requiredId(row.get("appointmentId")), null);
        stageInstanceService.start(node.getId(), null);
    }

    /** 取消面试：节点→已取消（幂等），不影响投递状态。 */
    private void cancelInterviewNode(Long candidateId, Long positionId, Map<String, Object> row)
    {
        Long instanceId = instanceIdOf(applicationStatusMapper.selectAppId(candidateId, positionId));
        if (instanceId == null) return;
        ProcessStageInstance node = stageInstanceService.getOrCreate(instanceId,
                nullableId(row.get("stageId")), nodeTypeOf(row), nodeNameOf(row),
                requiredId(row.get("appointmentId")), null);
        stageInstanceService.cancel(node.getId(), "面试安排取消");
    }

    /** 目标面试之前的所有必选笔试阶段均已通过，不能用任意笔试节点顶替。 */
    private boolean hasPassedRequiredExamNodes(Long candidateId, Long positionId, int stageOrder)
    {
        Long instanceId = instanceIdOf(applicationStatusMapper.selectAppId(candidateId, positionId));
        if (instanceId == null) return false;
        List<Long> required = new ArrayList<>(scheduleMapper.selectRequiredExamStageIdsBeforeCandidate(
                candidateId, positionId, stageOrder));
        if (required.isEmpty()) return true;
        for (ProcessStageInstance n : stageInstanceService.listNodes(instanceId))
        {
            if (n.getNodeType() == null || n.getNodeType() != ProcessStageInstance.TYPE_EXAM
                    || n.getResult() == null || n.getResult() != ProcessStageInstance.RESULT_PASS)
                continue;
            required.remove(n.getStageId());
            if (required.isEmpty()) return true;
        }
        return required.isEmpty();
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
