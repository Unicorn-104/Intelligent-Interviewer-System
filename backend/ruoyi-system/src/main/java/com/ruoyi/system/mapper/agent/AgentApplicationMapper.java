package com.ruoyi.system.mapper.agent;

import java.util.Date;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Options;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.domain.agent.AgentCandidate;
import com.ruoyi.system.domain.agent.AgentResumeRecord;
import com.ruoyi.system.domain.agent.AgentResumeOption;
import com.ruoyi.system.domain.agent.AgentResumeDetail;
import com.ruoyi.system.domain.agent.AgentResumeEducation;
import com.ruoyi.system.domain.agent.AgentResumeProject;
import com.ruoyi.system.domain.agent.AgentResumeSkill;
import com.ruoyi.system.domain.agent.AgentResumeWork;

/**
 * 求职者端简历和投递数据访问层。
 */
public interface AgentApplicationMapper
{
    List<AgentResumeOption> selectResumeOptions(@Param("userId") Long userId, @Param("jobId") Long jobId);

    AgentResumeOption selectResumeById(@Param("userId") Long userId, @Param("resumeId") Long resumeId);

    List<AgentResumeOption> selectResumeList(@Param("userId") Long userId);

    AgentResumeDetail selectResumeDetail(@Param("userId") Long userId, @Param("resumeId") Long resumeId);

    int countActiveResumes(@Param("userId") Long userId);

    @Options(useGeneratedKeys = true, keyProperty = "id", keyColumn = "rbs_id")
    int insertResume(AgentResumeRecord resume);

    int updateResumeBase(AgentResumeDetail resume);

    int deleteResumeEducation(@Param("resumeId") Long resumeId);

    int deleteResumeWork(@Param("resumeId") Long resumeId);

    int deleteResumeProject(@Param("resumeId") Long resumeId);

    int deleteResumeSkill(@Param("resumeId") Long resumeId);

    int insertResumeEducation(AgentResumeEducation education);

    int insertResumeWork(AgentResumeWork work);

    int insertResumeProject(AgentResumeProject project);

    int insertResumeSkill(AgentResumeSkill skill);

    int updateResumeFile(@Param("userId") Long userId, @Param("resumeId") Long resumeId,
            @Param("filePath") String filePath, @Param("fileName") String fileName,
            @Param("fileSize") Long fileSize);

    int softDeleteResume(@Param("userId") Long userId, @Param("resumeId") Long resumeId);

    int promoteFirstActiveResume(@Param("userId") Long userId);

    List<AgentApplication> selectApplicationList(@Param("userId") Long userId, @Param("status") String status);

    AgentApplication selectApplicationById(@Param("userId") Long userId, @Param("applicationId") Long applicationId);

    Long lockWithdrawalCandidate(@Param("userId") Long userId, @Param("applicationId") Long applicationId);

    int withdrawApplication(@Param("userId") Long userId, @Param("applicationId") Long applicationId);

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
