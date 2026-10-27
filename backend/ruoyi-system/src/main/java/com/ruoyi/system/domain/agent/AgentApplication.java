package com.ruoyi.system.domain.agent;

import java.math.BigDecimal;
import java.util.Date;
import java.util.List;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * 求职者端投递视图对象。
 */
public class AgentApplication
{
    private Long id;
    private Long candidateId;
    private Long jobId;
    private Long resumeId;
    private String jobTitle;
    private String companyName;
    private String companyLogoUrl;
    private String locationText;
    private BigDecimal salaryMin;
    private BigDecimal salaryMax;
    private String salaryText;
    private String resumeName;
    private Integer statusCode;
    private String status;
    private String statusText;
    private BigDecimal matchedScore;
    private Boolean duplicate;
    private Boolean canWithdraw;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private Date appliedAt;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private Date updatedAt;
    private List<AgentTimeline> timeline;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getCandidateId() { return candidateId; }
    public void setCandidateId(Long candidateId) { this.candidateId = candidateId; }
    public Long getJobId() { return jobId; }
    public void setJobId(Long jobId) { this.jobId = jobId; }
    public Long getResumeId() { return resumeId; }
    public void setResumeId(Long resumeId) { this.resumeId = resumeId; }
    public String getJobTitle() { return jobTitle; }
    public void setJobTitle(String jobTitle) { this.jobTitle = jobTitle; }
    public String getCompanyName() { return companyName; }
    public void setCompanyName(String companyName) { this.companyName = companyName; }
    public String getCompanyLogoUrl() { return companyLogoUrl; }
    public void setCompanyLogoUrl(String companyLogoUrl) { this.companyLogoUrl = companyLogoUrl; }
    public String getLocationText() { return locationText; }
    public void setLocationText(String locationText) { this.locationText = locationText; }
    public BigDecimal getSalaryMin() { return salaryMin; }
    public void setSalaryMin(BigDecimal salaryMin) { this.salaryMin = salaryMin; }
    public BigDecimal getSalaryMax() { return salaryMax; }
    public void setSalaryMax(BigDecimal salaryMax) { this.salaryMax = salaryMax; }
    public String getSalaryText() { return salaryText; }
    public void setSalaryText(String salaryText) { this.salaryText = salaryText; }
    public String getResumeName() { return resumeName; }
    public void setResumeName(String resumeName) { this.resumeName = resumeName; }
    public Integer getStatusCode() { return statusCode; }
    public void setStatusCode(Integer statusCode) { this.statusCode = statusCode; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getStatusText() { return statusText; }
    public void setStatusText(String statusText) { this.statusText = statusText; }
    public BigDecimal getMatchedScore() { return matchedScore; }
    public void setMatchedScore(BigDecimal matchedScore) { this.matchedScore = matchedScore; }
    public Boolean getDuplicate() { return duplicate; }
    public Boolean getCanWithdraw() { return canWithdraw; }
    public void setCanWithdraw(Boolean canWithdraw) { this.canWithdraw = canWithdraw; }
    public void setDuplicate(Boolean duplicate) { this.duplicate = duplicate; }
    public Date getAppliedAt() { return appliedAt; }
    public void setAppliedAt(Date appliedAt) { this.appliedAt = appliedAt; }
    public Date getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Date updatedAt) { this.updatedAt = updatedAt; }
    public List<AgentTimeline> getTimeline() { return timeline; }
    public void setTimeline(List<AgentTimeline> timeline) { this.timeline = timeline; }
}
