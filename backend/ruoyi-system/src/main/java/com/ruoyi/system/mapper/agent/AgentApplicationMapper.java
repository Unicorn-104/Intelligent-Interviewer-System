package com.ruoyi.system.mapper.agent;

import java.util.Date;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Options;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.domain.agent.AgentCandidate;
import com.ruoyi.system.domain.agent.AgentResumeOption;

/**
 * 求职者端简历和投递数据访问层。
 */
public interface AgentApplicationMapper
{
    List<AgentResumeOption> selectResumeOptions(@Param("userId") Long userId, @Param("jobId") Long jobId);

    AgentResumeOption selectResumeById(@Param("userId") Long userId, @Param("resumeId") Long resumeId);

    List<AgentApplication> selectApplicationList(@Param("userId") Long userId, @Param("status") String status);

    AgentApplication selectApplicationById(@Param("userId") Long userId, @Param("applicationId") Long applicationId);

    AgentApplication selectExistingApplication(@Param("userId") Long userId, @Param("jobId") Long jobId);

    Long selectCandidateId(@Param("userId") Long userId, @Param("companyId") Long companyId);

    @Options(useGeneratedKeys = true, keyProperty = "candidateId")
    int insertCandidate(AgentCandidate candidate);

    int updateCandidateResume(@Param("candidateId") Long candidateId, @Param("userId") Long userId,
            @Param("companyId") Long companyId, @Param("resumeId") Long resumeId);

    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insertApplication(AgentApplication application);

    List<com.ruoyi.system.domain.agent.AgentTimeline> selectTimeline(@Param("candidateId") Long candidateId,
            @Param("occurredAfter") Date occurredAfter);
}
