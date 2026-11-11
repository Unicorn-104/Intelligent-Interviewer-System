package com.ruoyi.web.controller.agent;

import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.utils.SecurityUtils;
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

    @Anonymous
    @GetMapping("/jobs")
    public AjaxResult list(@Valid AgentJobQuery query)
    {
        return success(jobService.selectJobs(query, currentUserId()));
    }

    @Anonymous
    @GetMapping("/jobs/categories")
    public AjaxResult categories()
    {
        return success(jobService.selectJobCategories());
    }

    @Anonymous
    @GetMapping("/jobs/filter-options")
    public AjaxResult filterOptions()
    {
        return success(jobService.selectJobFilterOptions());
    }

    @Anonymous
    @GetMapping("/jobs/{jobId}")
    public AjaxResult detail(@PathVariable("jobId") Long jobId)
    {
        AgentJob job = jobService.selectJob(jobId, currentUserId());
        return success(job);
    }

    private Long currentUserId()
    {
        Authentication authentication = SecurityUtils.getAuthentication();
        return authentication != null && authentication.getPrincipal() instanceof LoginUser user
                ? user.getUserId() : null;
    }
}
