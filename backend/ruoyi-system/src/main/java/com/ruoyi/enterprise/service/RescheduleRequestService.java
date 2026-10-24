package com.ruoyi.enterprise.service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.ResolverStyle;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.InterviewScheduleMapper;
import com.ruoyi.enterprise.mapper.RescheduleRequestMapper;
import com.ruoyi.system.mapper.DashboardMapper;

/** 改期申请只保存快照；审批通过与时段变更在同一事务提交，不发送通知。 */
@Service
public class RescheduleRequestService
{
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("uuuu-MM-dd HH:mm:ss")
            .withResolverStyle(ResolverStyle.STRICT);
    @Autowired private RescheduleRequestMapper requestMapper;
    @Autowired private InterviewScheduleMapper scheduleMapper;
    @Autowired private DashboardMapper dashboardMapper;
    @Autowired private IInterviewScheduleService scheduleService;

    public List<Map<String, Object>> list(Long userId, String status, Integer pageNum, Integer pageSize)
    {
        Long companyId = company(userId);
        Integer code = status == null ? null : switch (status) {
            case "pending" -> 0;
            case "approved" -> 1;
            case "rejected" -> 2;
            default -> throw new ServiceException("审批状态不正确");
        };
        pagination(pageNum, pageSize);
        PageUtils.startPage(pageNum, pageSize);
        return requestMapper.selectCompanyRequests(companyId, code);
    }

    public List<Map<String, Object>> own(Long userId, Integer pageNum, Integer pageSize)
    {
        id(userId);
        pagination(pageNum, pageSize);
        PageUtils.startPage(pageNum, pageSize);
        return requestMapper.selectOwnRequests(userId);
    }

    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> submit(Long userId, Long appointmentId, String newStartTime, String reason)
    {
        id(userId);
        id(appointmentId);
        String explanation = text(reason, true, "申请原因");
        Map<String, Object> appointment = requestMapper.selectAppointment(appointmentId);
        requireOwn(userId, appointment);
        scheduleMapper.lockCandidate(number(appointment, "candidateId"));
        requestMapper.lockAppointment(appointmentId);
        appointment = requestMapper.selectAppointment(appointmentId);
        requireOwn(userId, appointment);
        requireUpcoming(appointment);
        if (requestMapper.countPending(appointmentId) > 0)
            throw new ServiceException("该面试已有待审批申请，请勿重复提交");
        LocalDateTime start = time(newStartTime);
        if (!start.isAfter(now())) throw new ServiceException("申请时段必须晚于当前时间");
        LocalDateTime oldStart = time(appointment.get("startTime"));
        long seconds = Duration.between(oldStart, time(appointment.get("endTime"))).getSeconds();
        if (start.getSecond() != 0 || oldStart.getSecond() != 0 || seconds < 60
                || seconds > 86400 || seconds % 60 != 0)
            throw new ServiceException("面试时间须按分钟安排，时长为1至1440分钟");
        if (start.equals(oldStart)) throw new ServiceException("新时段不能与原时段相同");
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("appointmentId", appointmentId);
        row.put("companyId", number(appointment, "companyId"));
        row.put("candidateId", number(appointment, "candidateId"));
        row.put("requesterId", userId);
        row.put("originalStartTime", oldStart.format(TIME));
        row.put("originalEndTime", appointment.get("endTime"));
        row.put("originalInterviewerId", number(appointment, "interviewerId"));
        row.put("newStartTime", start.format(TIME));
        row.put("newEndTime", start.plusSeconds(seconds).format(TIME));
        row.put("reason", explanation);
        requestMapper.insertRequest(row);
        return requestMapper.selectRequest(number(row, "requestId"), number(row, "companyId"));
    }

    @Transactional(rollbackFor = Exception.class, isolation = Isolation.READ_COMMITTED)
    public Map<String, Object> review(Long userId, Long requestId, String decision, String note)
    {
        id(requestId);
        Long companyId = company(userId);
        if (!"approved".equals(decision) && !"rejected".equals(decision))
            throw new ServiceException("仅支持通过或驳回申请");
        String reviewNote = text(note, "rejected".equals(decision), "审批说明");
        Map<String, Object> row = requestMapper.selectRequest(requestId, companyId);
        if (row == null) throw new ServiceException("申请不存在或无权访问");
        scheduleMapper.lockCandidate(number(row, "candidateId"));
        requestMapper.lockAppointment(number(row, "appointmentId"));
        if (requestMapper.lockRequest(requestId, companyId) == null)
            throw new ServiceException("申请不存在或无权访问");
        row = requestMapper.selectRequest(requestId, companyId);
        if (row == null) throw new ServiceException("申请不存在或无权访问");
        if (!"pending".equals(row.get("status")))
        {
            // 网络结果不确定后的同结果重试幂等，不再次改期，也不覆盖首次审批人或说明。
            if (decision.equals(row.get("status"))) return row;
            throw new ServiceException("该申请已处理，请刷新列表");
        }
        if (number(row, "requesterId").equals(userId))
            throw new ServiceException("不能审批本人提交的改期申请");
        if ("approved".equals(decision))
        {
            Map<String, Object> appointment = requestMapper.selectAppointment(number(row, "appointmentId"));
            requireUpcoming(appointment);
            if (!Objects.equals(appointment.get("startTime"), row.get("originalStartTime"))
                    || !Objects.equals(appointment.get("endTime"), row.get("originalEndTime"))
                    || !Objects.equals(number(appointment, "interviewerId"), number(row, "originalInterviewerId")))
                throw new ServiceException("原面试安排已变化，请驳回后重新申请");
            if (!number(appointment, "companyId").equals(companyId)
                    || !number(appointment, "candidateId").equals(number(row, "candidateId")))
                throw new ServiceException("面试归属已变化，无法审批");
            // 经 Spring 代理调用原调度事务，沿用冲突、阶段先后和面试官归属校验。
            scheduleService.reschedule(userId, number(row, "appointmentId"),
                    String.valueOf(row.get("newStartTime")), null, null);
        }
        int changed = requestMapper.updateDecision(requestId, companyId,
                "approved".equals(decision) ? 1 : 2, userId, reviewNote);
        if (changed != 1) throw new ServiceException("申请状态已变化，请刷新核对");
        return requestMapper.selectRequest(requestId, companyId);
    }

    private Long company(Long userId)
    {
        id(userId);
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        if (companyId == null || companyId <= 0) throw new ServiceException("请先完成企业绑定");
        return companyId;
    }

    private void requireOwn(Long userId, Map<String, Object> appointment)
    {
        if (appointment == null || !userId.equals(number(appointment, "candidateUserId")))
            throw new ServiceException("面试不存在或不属于当前候选人");
    }

    private void requireUpcoming(Map<String, Object> row)
    {
        if (row == null || !("0".equals(String.valueOf(row.get("status")))
                || "1".equals(String.valueOf(row.get("status"))))
                || !time(row.get("startTime")).isAfter(now()))
            throw new ServiceException("仅未开始且未取消的面试可以申请或通过改期");
    }

    private LocalDateTime now() { return LocalDateTime.now(ZoneOffset.ofHours(8)); }
    private LocalDateTime time(Object value)
    {
        try
        {
            String raw = String.valueOf(value);
            if (raw.length() == 16) raw += ":00";
            return LocalDateTime.parse(raw, TIME);
        }
        catch (RuntimeException ex) { throw new ServiceException("时间格式应为yyyy-MM-dd HH:mm[:ss]"); }
    }
    private Long number(Map<String, Object> row, String key)
    {
        try { Long value = Long.valueOf(String.valueOf(row.get(key))); id(value); return value; }
        catch (RuntimeException ex) { throw new ServiceException("申请关联数据无效"); }
    }
    private void id(Long value)
    {
        if (value == null || value <= 0) throw new ServiceException("标识须为正整数");
    }
    private String text(String raw, boolean required, String label)
    {
        String value = raw == null ? "" : raw.trim();
        if ((required && value.isEmpty()) || value.codePointCount(0, value.length()) > 500
                || value.chars().anyMatch(c -> Character.isISOControl(c) && c != '\n'))
            throw new ServiceException(label + "须为1至500字且不含控制字符");
        return value.isEmpty() ? null : value;
    }
    private void pagination(Integer page, Integer size)
    {
        if (page == null || size == null || page < 1 || page > 100000 || size < 1 || size > 100)
            throw new ServiceException("分页参数超出范围");
    }
}
