package com.ruoyi.web.controller.enterprise;

import java.util.List;
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
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.IInterviewScheduleService;

/**
 * 企业端 - 智能预约调度
 *
 * <p>依据《业务功能分析》UC-07（候选人自主预约与智能排期）、
 * UC-08（面试官日历同步与冲突检测）、UC-09（候选人自助改期）：
 * 面试邀约/日程/面试官忙闲/改期（原时段自动释放回退可用池）/提醒。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/interview")
public class InterviewScheduleController extends BaseController
{
    @Autowired
    private IInterviewScheduleService scheduleService;

    /**
     * UC-07：面试日程列表（状态/时间范围筛选）
     */
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) Integer status,
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(scheduleService.listAppointments(getUserId(), status, from, to, pageNum, pageSize));
    }

    /**
     * UC-07：发起面试邀约（占用时段 + 创建预约，生成专属会议链接）
     */
    @PostMapping("/invite")
    public AjaxResult invite(@RequestBody Map<String, Object> body)
    {
        return success(scheduleService.invite(getUserId(), asLong(body.get("candidateId")),
                asLong(body.get("positionId")), asLong(body.get("stageId")),
                asLong(body.get("interviewerId")),
                body.get("startTime") == null ? null : String.valueOf(body.get("startTime")),
                asInt(body.get("durationMin"), 45)));
    }

    /**
     * UC-08：面试官日历忙闲状态（冲突检测依据）
     */
    @GetMapping("/calendar/{interviewerId}")
    public AjaxResult calendar(@PathVariable("interviewerId") Long interviewerId,
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to)
    {
        return success(scheduleService.listInterviewerSlots(getUserId(), interviewerId, from, to));
    }

    /**
     * UC-09：面试改期（原时段自动释放回退可用池，新时段原子占用）
     */
    @PutMapping("/{appointmentId}/reschedule")
    public AjaxResult reschedule(@PathVariable("appointmentId") Long appointmentId,
            @RequestBody Map<String, Object> body)
    {
        return success(scheduleService.reschedule(getUserId(), appointmentId,
                body.get("newStartTime") == null ? null : String.valueOf(body.get("newStartTime")),
                asInt(body.get("durationMin"), null), asLong(body.get("interviewerId"))));
    }

    /**
     * UC-07 步骤11：面试提醒（面试前 24h/1h 催办入口）
     */
    @PostMapping("/{appointmentId}/remind")
    public AjaxResult remind(@PathVariable("appointmentId") Long appointmentId)
    {
        return success(scheduleService.remind(getUserId(), appointmentId));
    }

    @PostMapping("/invite/stages")
    public AjaxResult inviteStages(@RequestBody Map<String, Object> body)
    {
        if (!(body.get("stages") instanceof List<?> rows) || rows.isEmpty()
                || rows.stream().anyMatch(row -> !(row instanceof Map)))
        {
            throw new ServiceException("请填写各阶段面试安排");
        }
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> stages = (List<Map<String, Object>>) body.get("stages");
        return success(scheduleService.inviteStages(getUserId(), asLong(body.get("candidateId")),
                asLong(body.get("positionId")), stages));
    }

    @GetMapping("/candidate-plan")
    public AjaxResult candidatePlan(@RequestParam Long candidateId, @RequestParam Long positionId)
    {
        return success(scheduleService.candidateAppointments(getUserId(), candidateId, positionId));
    }

    /**
     * UC-07：确认/取消面试安排（1-已确认，2-已取消）
     */
    @PutMapping("/{appointmentId}/status")
    public AjaxResult updateStatus(@PathVariable("appointmentId") Long appointmentId,
            @RequestBody Map<String, Object> body)
    {
        return success(scheduleService.updateStatus(getUserId(), appointmentId, asInt(body.get("status"), null)));
    }

    private Long asLong(Object v)
    {
        if (v == null)
        {
            return null;
        }
        if (v instanceof Number)
        {
            return ((Number) v).longValue();
        }
        String s = v.toString().trim();
        return s.isEmpty() ? null : Long.valueOf(s);
    }

    private Integer asInt(Object v, Integer defaultValue)
    {
        if (v == null)
        {
            return defaultValue;
        }
        if (v instanceof Number)
        {
            return ((Number) v).intValue();
        }
        String s = v.toString().trim();
        return s.isEmpty() ? defaultValue : Integer.valueOf(s);
    }
}
