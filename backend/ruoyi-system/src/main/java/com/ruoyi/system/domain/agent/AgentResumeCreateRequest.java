package com.ruoyi.system.domain.agent;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 求职者端简历创建请求。
 */
public class AgentResumeCreateRequest
{
    @NotBlank(message = "简历名称不能为空")
    @Size(max = 100, message = "简历名称不能超过100个字符")
    private String resumeName;

    @Size(max = 50, message = "求职方向不能超过50个字符")
    private String jobDirection;

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
}
