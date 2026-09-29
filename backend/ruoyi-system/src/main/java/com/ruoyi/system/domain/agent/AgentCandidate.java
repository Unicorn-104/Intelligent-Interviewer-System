package com.ruoyi.system.domain.agent;

/**
 * 企业维度人才档案写入对象。
 */
public class AgentCandidate
{
    private Long candidateId;
    private Long userId;
    private Long companyId;
    private Long resumeId;

    public Long getCandidateId() { return candidateId; }
    public void setCandidateId(Long candidateId) { this.candidateId = candidateId; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public Long getCompanyId() { return companyId; }
    public void setCompanyId(Long companyId) { this.companyId = companyId; }
    public Long getResumeId() { return resumeId; }
    public void setResumeId(Long resumeId) { this.resumeId = resumeId; }
}
