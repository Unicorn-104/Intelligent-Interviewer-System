package com.ruoyi.web.controller.agent;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.agent.AgentApplicationCreateRequest;
import com.ruoyi.system.domain.agent.AgentApplicationQuery;
import com.ruoyi.system.domain.agent.AgentResumeCreateRequest;
import com.ruoyi.system.domain.agent.AgentResumeUpdateRequest;
import com.ruoyi.system.service.agent.IAgentApplicationService;

/**
 * 求职者端简历与投递接口。
 */
@Validated
@RestController
@RequestMapping("/agent/v1")
public class AgentApplicationController extends BaseController
{
    @Autowired
    private IAgentApplicationService applicationService;

    @GetMapping("/jobs/{jobId}/resume-options")
    public AjaxResult resumeOptions(@PathVariable("jobId") Long jobId)
    {
        return success(applicationService.selectResumeOptions(getUserId(), jobId));
    }

    @PostMapping("/resumes")
    public AjaxResult createResume(@Valid @RequestBody AgentResumeCreateRequest request)
    {
        return success(applicationService.createResume(getUserId(), request));
    }

    @GetMapping("/resumes")
    public AjaxResult resumes()
    {
        return success(applicationService.selectResumes(getUserId()));
    }

    @GetMapping("/resumes/{resumeId}")
    public AjaxResult resume(@PathVariable("resumeId") Long resumeId)
    {
        return success(applicationService.selectResume(getUserId(), resumeId));
    }

    @PutMapping("/resumes/{resumeId}")
    public AjaxResult updateResume(@PathVariable("resumeId") Long resumeId,
            @Valid @RequestBody AgentResumeUpdateRequest request)
    {
        return success(applicationService.updateResume(getUserId(), resumeId, request));
    }

    @PostMapping("/resumes/{resumeId}/file")
    public AjaxResult uploadResumeFile(@PathVariable("resumeId") Long resumeId,
            @RequestParam("file") MultipartFile file) throws Exception
    {
        return success(applicationService.uploadResumeFile(getUserId(), resumeId, file));
    }

    @DeleteMapping("/resumes/{resumeId}")
    public AjaxResult deleteResume(@PathVariable("resumeId") Long resumeId)
    {
        applicationService.deleteResume(getUserId(), resumeId);
        return success();
    }

    @PostMapping("/applications")
    public AjaxResult create(@Valid @RequestBody AgentApplicationCreateRequest request)
    {
        return success(applicationService.createApplication(getUserId(), request));
    }

    @GetMapping("/applications")
    public AjaxResult list(@Valid AgentApplicationQuery query)
    {
        return success(applicationService.selectApplications(query, getUserId()));
    }

    @GetMapping("/applications/{applicationId}")
    public AjaxResult detail(@PathVariable("applicationId") Long applicationId)
    {
        return success(applicationService.selectApplication(getUserId(), applicationId));
    }
}
