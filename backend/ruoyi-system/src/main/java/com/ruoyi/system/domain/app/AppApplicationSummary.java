package com.ruoyi.system.domain.app;

import java.io.Serializable;

/** C-App 首页投递摘要。 */
public class AppApplicationSummary implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long applicationId;
    private String title;
    private String company;
    private Integer status;
    private String statusLabel;
    private Integer progress;

    public Long getApplicationId() { return applicationId; }
    public void setApplicationId(Long applicationId) { this.applicationId = applicationId; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getCompany() { return company; }
    public void setCompany(String company) { this.company = company; }
    public Integer getStatus() { return status; }
    public void setStatus(Integer status) { this.status = status; }
    public String getStatusLabel() { return statusLabel; }
    public void setStatusLabel(String statusLabel) { this.statusLabel = statusLabel; }
    public Integer getProgress() { return progress; }
    public void setProgress(Integer progress) { this.progress = progress; }
}
