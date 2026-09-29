package com.ruoyi.system.domain.agent;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * 投递进度节点。
 */
public class AgentTimeline
{
    private String stage;
    private String state;
    private String title;
    private String description;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private Date occurredAt;

    public AgentTimeline()
    {
    }

    public AgentTimeline(String stage, String state, String title, String description, Date occurredAt)
    {
        this.stage = stage;
        this.state = state;
        this.title = title;
        this.description = description;
        this.occurredAt = occurredAt;
    }

    public String getStage() { return stage; }
    public void setStage(String stage) { this.stage = stage; }
    public String getState() { return state; }
    public void setState(String state) { this.state = state; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public Date getOccurredAt() { return occurredAt; }
    public void setOccurredAt(Date occurredAt) { this.occurredAt = occurredAt; }
}
