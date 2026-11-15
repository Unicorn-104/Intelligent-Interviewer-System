package com.ruoyi.web.controller.app;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestBody;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.system.service.app.IAppJobService;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.service.agent.IAgentJobService;
import com.ruoyi.common.exception.ServiceException;
import jakarta.validation.Valid;

/** C-App 首页、岗位搜索与投递接口。 */
@RestController
@RequestMapping("/app")
public class AppJobController extends BaseController
{
    @Autowired
    private IAppJobService jobService;

    @Autowired
    private IAgentJobService publicJobService;

    @GetMapping("/home")
    public AjaxResult home(@RequestParam(required = false) String filter)
    {
        return success(jobService.selectHomeData(getUserId(), filter));
    }

    @GetMapping("/jobs")
    public AjaxResult jobs(@RequestParam(required = false) String keyword,
                           @RequestParam(required = false) String filter,
                           @RequestParam(required = false, defaultValue = "20") Integer limit)
    {
        return success(jobService.selectJobs(getOptionalUserId(), keyword, filter, limit));
    }

    /** 岗位浏览允许匿名访问；投递等写操作仍使用 {@link #getUserId()} 强制鉴权。 */
    private Long getOptionalUserId()
    {
        var authentication = SecurityUtils.getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof LoginUser loginUser))
        {
            return null;
        }
        return loginUser.getUserId();
    }

    /** Public searches reuse the validated paging/filter contract without personal context. */
    @GetMapping("/jobs/search")
    public AjaxResult publicSearch(@Valid AgentJobQuery query)
    {
        query.setResumeId(null);
        return success(publicJobService.selectJobs(query, null));
    }

    @GetMapping("/jobs/filter-options")
    public AjaxResult publicFilterOptions()
    {
        return success(publicJobService.selectJobFilterOptions());
    }

    @GetMapping("/jobs/public/{positionId}")
    public AjaxResult publicDetail(@PathVariable Long positionId)
    {
        AgentJob job = publicJobService.selectJob(positionId, null);
        if (job == null || !Integer.valueOf(1).equals(job.getStatusCode()))
        {
            throw new ServiceException("岗位不存在或已下线", 404);
        }
        return success(job);
    }

    public record ApplyRequest(Long resumeId) { }

    @Log(title = "C端岗位投递", businessType = BusinessType.INSERT)
    @PostMapping("/jobs/{positionId}/apply")
    public AjaxResult apply(@PathVariable Long positionId, @RequestBody(required = false) ApplyRequest request)
    {
        jobService.apply(getUserId(), positionId, request == null ? null : request.resumeId());
        return success("投递成功");
    }
}
