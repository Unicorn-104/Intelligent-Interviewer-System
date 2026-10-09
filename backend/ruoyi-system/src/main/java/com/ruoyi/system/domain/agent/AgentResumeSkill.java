package com.ruoyi.system.domain.agent;

/**
 * 求职者端简历技能标签。
 */
public class AgentResumeSkill
{
    private Long id;
    private Long resumeId;
    private String name;
    private Integer level;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getResumeId() { return resumeId; }
    public void setResumeId(Long resumeId) { this.resumeId = resumeId; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public Integer getLevel() { return level; }
    public void setLevel(Integer level) { this.level = level; }
}
