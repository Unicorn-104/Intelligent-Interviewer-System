package com.ruoyi.web.controller.enterprise;

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
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.IScreeningService;

/**
 * 企业端 - AI 初筛与智能匹配
 *
 * <p>依据《业务功能分析》UC-04（硬性条件自动过滤）、
 * UC-05（AI 多维度匹配与评分排序）、UC-06（短名单 HR 复核）：
 * 基于简历证据生成六维评分及简短推荐理由
 * → 降序短名单 Top N → 可解释推荐报告与个性化招呼语 → HR 复核。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/screening")
public class ScreeningController extends BaseController
{
    @Autowired
    private IScreeningService screeningService;

    /**
     * UC-04/UC-05 步骤1：触发 AI 初筛任务（按岗位发起，taskId 即岗位ID）
     */
    @PostMapping("/tasks")
    public AjaxResult trigger(@RequestBody Map<String, Object> body)
    {
        Long positionId = asLong(body.get("positionId"));
        Integer topN = asInt(body.get("topN"), 20);
        return success(screeningService.triggerScreening(getUserId(), positionId, topN));
    }

    /**
     * UC-05 步骤1：筛选任务列表（按岗位聚合）
     */
    @GetMapping("/tasks")
    public TableDataInfo tasks(@RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(screeningService.listTasks(getUserId(), pageNum, pageSize));
    }

    @PostMapping("/tasks/async")
    public AjaxResult triggerAsync(@RequestBody Map<String, Object> body)
    {
        Long positionId = asLong(body.get("positionId"));
        Integer topN = asInt(body.get("topN"), 20);
        // Omitted/false keeps the original API contract; only an explicit JSON true forces a refresh.
        Object full = body.get("fullAnalysis");
        if (full != null && !(full instanceof Boolean))
            throw new com.ruoyi.common.exception.ServiceException("fullAnalysis须为布尔值");
        return success(Boolean.TRUE.equals(full)
                ? screeningService.triggerScreeningAsync(getUserId(), positionId, topN, true)
                : screeningService.triggerScreeningAsync(getUserId(), positionId, topN));
    }

    @GetMapping("/tasks/{taskId}/status")
    public AjaxResult taskStatus(@PathVariable("taskId") Long taskId)
    {
        return success(screeningService.getTaskStatus(getUserId(), taskId));
    }

    /**
     * UC-05 步骤3-4：匹配度评分与维度明细（降序）
     */
    @GetMapping("/tasks/{taskId}/results")
    public AjaxResult results(@PathVariable("taskId") Long taskId)
    {
        return success(screeningService.listResults(getUserId(), taskId));
    }

    /**
     * UC-05 步骤5：推荐短名单（Top N 降序）
     */
    @GetMapping("/tasks/{taskId}/shortlist")
    public AjaxResult shortlist(@PathVariable("taskId") Long taskId,
            @RequestParam(required = false) Integer topN)
    {
        return success(screeningService.listShortlist(getUserId(), taskId, topN));
    }

    /**
     * UC-05 步骤6-7：AI 推荐报告（匹配点/风险点/待核实点，含原文引用）
     */
    @GetMapping("/results/{resultId}/report")
    public AjaxResult report(@PathVariable("resultId") Long resultId)
    {
        return success(screeningService.getReport(getUserId(), resultId));
    }

    /**
     * UC-05 步骤8：Top 3 个性化招呼语
     */
    @GetMapping("/results/{resultId}/greeting")
    public AjaxResult greeting(@PathVariable("resultId") Long resultId)
    {
        return success(screeningService.getGreeting(getUserId(), resultId));
    }

    /**
     * UC-06：HR 短名单复核（确认通过 / 调整评分）
     */
    @PutMapping("/results/{resultId}/review")
    public AjaxResult review(@PathVariable("resultId") Long resultId, @RequestBody Map<String, Object> body)
    {
        Boolean approved = body.get("approved") == null ? null : Boolean.valueOf(String.valueOf(body.get("approved")));
        Double adjustScore = body.get("adjustScore") == null ? null : Double.valueOf(String.valueOf(body.get("adjustScore")));
        return success(screeningService.reviewResult(getUserId(), resultId, approved, adjustScore));
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
