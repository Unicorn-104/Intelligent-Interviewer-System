package com.ruoyi.system.domain.agent;

/**
 * 求职者端简历基础记录。
 */
public class AgentResumeRecord
{
    private Long id;
    private Long userId;
    private String resumeName;
    private String jobDirection;
    private Integer isDefault;

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public Long getUserId()
    {
        return userId;
    }

    public void setUserId(Long userId)
    {
        this.userId = userId;
    }

    public String getResumeName()
    {
        return resumeName;
    }

    public void setResumeName(String resumeName)
    {
        this.resumeName = resumeName;
    }

    public String getJobDirection()
    {
        return jobDirection;
    }

    public void setJobDirection(String jobDirection)
    {
        this.jobDirection = jobDirection;
    }

    public Integer getIsDefault()
    {
        return isDefault;
    }

    public void setIsDefault(Integer isDefault)
    {
        this.isDefault = isDefault;
    }
}
