package com.ruoyi.system.domain.app;

import java.io.Serializable;
import java.util.List;

/** C-App 首页聚合数据。 */
public class AppHomeData implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Integer newOpportunityCount;
    private Integer highMatchCount;
    private List<AppJob> recommendations;
    private List<AppApplicationSummary> applications;

    public Integer getNewOpportunityCount() { return newOpportunityCount; }
    public void setNewOpportunityCount(Integer newOpportunityCount) { this.newOpportunityCount = newOpportunityCount; }
    public Integer getHighMatchCount() { return highMatchCount; }
    public void setHighMatchCount(Integer highMatchCount) { this.highMatchCount = highMatchCount; }
    public List<AppJob> getRecommendations() { return recommendations; }
    public void setRecommendations(List<AppJob> recommendations) { this.recommendations = recommendations; }
    public List<AppApplicationSummary> getApplications() { return applications; }
    public void setApplications(List<AppApplicationSummary> applications) { this.applications = applications; }
}
