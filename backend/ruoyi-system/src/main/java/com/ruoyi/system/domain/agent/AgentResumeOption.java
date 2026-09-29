package com.ruoyi.system.domain.agent;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * 投递时可选简历。
 */
public class AgentResumeOption
{
    private Long id;
    private String name;
    private String jobDirection;
    private Boolean isDefault;
    private Integer completion;
    private Integer matchScore;
    private Boolean recommended;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private Date updatedAt;
    private Integer usedApplicationCount;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getJobDirection() { return jobDirection; }
    public void setJobDirection(String jobDirection) { this.jobDirection = jobDirection; }
    public Boolean getIsDefault() { return isDefault; }
    public void setIsDefault(Boolean isDefault) { this.isDefault = isDefault; }
    public Integer getCompletion() { return completion; }
    public void setCompletion(Integer completion) { this.completion = completion; }
    public Integer getMatchScore() { return matchScore; }
    public void setMatchScore(Integer matchScore) { this.matchScore = matchScore; }
    public Boolean getRecommended() { return recommended; }
    public void setRecommended(Boolean recommended) { this.recommended = recommended; }
    public Date getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Date updatedAt) { this.updatedAt = updatedAt; }
    public Integer getUsedApplicationCount() { return usedApplicationCount; }
    public void setUsedApplicationCount(Integer usedApplicationCount) { this.usedApplicationCount = usedApplicationCount; }
}
