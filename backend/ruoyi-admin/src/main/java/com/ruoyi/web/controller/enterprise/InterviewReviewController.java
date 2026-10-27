package com.ruoyi.web.controller.enterprise;

import java.util.LinkedHashMap;
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
import com.ruoyi.enterprise.service.IInterviewReviewService;

/**
 * 企业端 - HR 终审与级联流转
 *
 * <p>依据《业务功能分析》UC-12 步骤7-10（评估报告推送终审工作台，
 * HR 确认通过/调整后通过/驳回淘汰）与 UC-15（级联面试自动流转）：
 * 终面通过 → Offer 流程（由 Offer 接口触发）；非终面通过 → 自动创建
 * 下一轮预约任务；驳回 → 淘汰归档 + 感谢信。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/review")
public class InterviewReviewController extends BaseController
{
    @Autowired
    private IInterviewReviewService reviewService;

    /**
     * UC-12 步骤7：待终审列表（HR 审核状态：0-未审核，1-已确认，2-已修改）
     */
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(reviewService.listReviews(getUserId(), status, pageNum, pageSize));
    }

    /**
     * UC-12 步骤7：评估报告详情（五维评分卡 + 评语 + 回放链接）
     */
    @GetMapping("/{sessionId}")
    public AjaxResult detail(@PathVariable("sessionId") Long sessionId)
    {
        return success(reviewService.getReviewDetail(getUserId(), sessionId));
    }

    /**
     * UC-12 步骤8-9：确认通过（终面 → Offer 流程；非终面 → 级联下一轮 UC-15）
     */
    @PutMapping("/{sessionId}/confirm")
    public AjaxResult confirm(@PathVariable("sessionId") Long sessionId, @RequestBody(required = false) Map<String, Object> body)
    {
        Boolean isFinal = body == null ? null : asBool(body.get("isFinal"));
        Integer recommendation = body == null || body.get("recommendation") == null ? null
                : Integer.valueOf(String.valueOf(body.get("recommendation")));
        String comment = body == null || body.get("comment") == null ? null : String.valueOf(body.get("comment"));
        return success(reviewService.confirm(getUserId(), sessionId, isFinal, recommendation, comment));
    }

    /**
     * UC-12 步骤8：调整后通过（HR 修改五维评分后确认）
     */
    @PutMapping("/{sessionId}/adjust")
    public AjaxResult adjust(@PathVariable("sessionId") Long sessionId, @RequestBody Map<String, Object> body)
    {
        // 维度评分以数字键提交（1-5），recommendation/comment 为 HR 可选结论
        Map<String, Object> dims = new LinkedHashMap<>();
        if (body != null)
        {
            body.forEach((key, value) -> {
                if (key != null && key.matches("\\d+"))
                {
                    dims.put(key, value);
                }
            });
        }
        Integer recommendation = body == null || body.get("recommendation") == null ? null
                : Integer.valueOf(String.valueOf(body.get("recommendation")));
        String comment = body == null || body.get("comment") == null ? null : String.valueOf(body.get("comment"));
        return success(reviewService.adjust(getUserId(), sessionId, dims, recommendation, comment));
    }

    /**
     * UC-12 步骤10：驳回淘汰（归档人才库 + 感谢信）
     */
    @PutMapping("/{sessionId}/reject")
    public AjaxResult reject(@PathVariable("sessionId") Long sessionId, @RequestBody(required = false) Map<String, Object> body)
    {
        String reason = body == null ? null : (body.get("reason") == null ? null : String.valueOf(body.get("reason")));
        return success(reviewService.reject(getUserId(), sessionId, reason));
    }

    /**
     * UC-15：级联流转（非终面通过后创建下一轮预约任务，按级联规则评分阈值判断）
     */
    @PostMapping("/{sessionId}/cascade")
    public AjaxResult cascade(@PathVariable("sessionId") Long sessionId)
    {
        return success(reviewService.cascade(getUserId(), sessionId));
    }

    private Boolean asBool(Object v)
    {
        if (v == null)
        {
            return null;
        }
        if (v instanceof Boolean)
        {
            return (Boolean) v;
        }
        return Boolean.valueOf(String.valueOf(v));
    }
}
