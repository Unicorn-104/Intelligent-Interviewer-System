package com.ruoyi.web.controller.agent;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.service.agent.IAgentJobService;

/**
 * 求职者端岗位接口。
 */
@Validated
@RestController
@RequestMapping("/agent/v1")
public class AgentJobController extends BaseController
{
    @Autowired
    private IAgentJobService jobService;

    @GetMapping("/jobs")
    public AjaxResult list(@Valid AgentJobQuery query)
    {
        return success(jobService.selectJobs(query, getUserId()));
    }

    @GetMapping("/jobs/categories")
    public AjaxResult categories()
    {
        return success(jobService.selectJobCategories());
    }

    @GetMapping("/jobs/filter-options")
    public AjaxResult filterOptions()
    {
        return success(jobService.selectJobFilterOptions());
    }

    @GetMapping("/jobs/{jobId}")
    public AjaxResult detail(@PathVariable("jobId") Long jobId)
    {
        AgentJob job = jobService.selectJob(jobId, getUserId());
        return success(job);
    }
}
