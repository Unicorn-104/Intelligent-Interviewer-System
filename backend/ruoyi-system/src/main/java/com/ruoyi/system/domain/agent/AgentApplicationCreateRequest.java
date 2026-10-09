package com.ruoyi.system.domain.agent;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 创建岗位投递请求。
 */
public class AgentApplicationCreateRequest
{
    @NotNull(message = "岗位不能为空")
    private Long jobId;

    @NotNull(message = "简历不能为空")
    private Long resumeId;

    @NotBlank(message = "投递协议版本不能为空")
    private String consentVersion;

    public Long getJobId() { return jobId; }
    public void setJobId(Long jobId) { this.jobId = jobId; }
    public Long getResumeId() { return resumeId; }
    public void setResumeId(Long resumeId) { this.resumeId = resumeId; }
    public String getConsentVersion() { return consentVersion; }
    public void setConsentVersion(String consentVersion) { this.consentVersion = consentVersion; }
}
