package com.ruoyi.web.controller.agent;

import java.nio.charset.StandardCharsets;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
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
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.agent.AgentApplicationCreateRequest;
import com.ruoyi.system.domain.agent.AgentApplicationQuery;
import com.ruoyi.system.domain.agent.AgentResumeCreateRequest;
import com.ruoyi.system.domain.agent.AgentResumeUpdateRequest;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.domain.app.AppResumeAttachmentDocument;
import com.ruoyi.system.service.agent.IAgentResumeAttachmentService;
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

    @Autowired
    private IAgentResumeAttachmentService attachmentService;

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

    @PostMapping(value = "/resumes/parse-pdf", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AjaxResult parseResumePdf(@RequestParam("file") MultipartFile file) throws Exception
    {
        return success(applicationService.parseResumePdf(file));
    }

    @PostMapping(value = "/resumes/import-pdf", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AjaxResult createResumeWithPdf(@Valid @RequestPart("resume") AgentResumeUpdateRequest request,
            @RequestPart("file") MultipartFile file) throws Exception
    {
        return success(applicationService.createResumeWithPdf(getUserId(), request, file));
    }

    @PostMapping(value = "/resumes/{resumeId}/import-pdf", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AjaxResult updateResumeWithPdf(@PathVariable("resumeId") Long resumeId,
            @Valid @RequestPart("resume") AgentResumeUpdateRequest request,
            @RequestPart("file") MultipartFile file) throws Exception
    {
        return success(applicationService.updateResumeWithPdf(getUserId(), resumeId, request, file));
    }

    @GetMapping("/resumes/{resumeId}/file")
    public ResponseEntity<Resource> resumeFile(@PathVariable("resumeId") Long resumeId)
    {
        AppResumePdfDocument document = applicationService.selectResumePdf(getUserId(), resumeId);
        Resource resource = new FileSystemResource(document.path());
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(document.name(), StandardCharsets.UTF_8).build().toString())
                .body(resource);
    }
    @PostMapping("/resumes/{resumeId}/file")
    public AjaxResult uploadResumeFile(@PathVariable("resumeId") Long resumeId,
            @RequestParam("file") MultipartFile file) throws Exception
    {
        return success(applicationService.uploadResumeFile(getUserId(), resumeId, file));
    }

    @GetMapping("/resumes/{resumeId}/attachments")
    public AjaxResult attachments(@PathVariable("resumeId") Long resumeId)
    {
        return success(attachmentService.list(getUserId(), resumeId));
    }

    @PostMapping(value = "/resumes/{resumeId}/attachments", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AjaxResult addAttachments(@PathVariable("resumeId") Long resumeId,
            @RequestParam("files") MultipartFile[] files) throws Exception
    {
        return success(attachmentService.add(getUserId(), resumeId, files));
    }

    @GetMapping("/resumes/{resumeId}/attachments/{attachmentId}/file")
    public ResponseEntity<Resource> attachmentFile(@PathVariable("resumeId") Long resumeId,
            @PathVariable("attachmentId") Long attachmentId)
    {
        AppResumeAttachmentDocument document = attachmentService.file(getUserId(), resumeId, attachmentId);
        MediaType mediaType;
        try
        {
            mediaType = MediaType.parseMediaType(document.contentType());
        }
        catch (IllegalArgumentException error)
        {
            mediaType = MediaType.APPLICATION_OCTET_STREAM;
        }
        return ResponseEntity.ok().contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(document.name(), StandardCharsets.UTF_8).build().toString())
                .body(new FileSystemResource(document.path()));
    }

    @DeleteMapping("/resumes/{resumeId}/attachments/{attachmentId}")
    public AjaxResult deleteAttachment(@PathVariable("resumeId") Long resumeId,
            @PathVariable("attachmentId") Long attachmentId)
    {
        return success(attachmentService.delete(getUserId(), resumeId, attachmentId));
    }    @DeleteMapping("/resumes/{resumeId}")
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

    @PostMapping("/applications/{applicationId}/withdraw")
    public AjaxResult withdraw(@PathVariable("applicationId") Long applicationId)
    {
        return success(applicationService.withdrawApplication(getUserId(), applicationId));
    }
}
