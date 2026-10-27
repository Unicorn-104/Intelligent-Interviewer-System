package com.ruoyi.system.service.agent;

import java.util.List;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.domain.agent.AgentApplicationCreateRequest;
import com.ruoyi.system.domain.agent.AgentApplicationQuery;
import com.ruoyi.system.domain.agent.AgentPage;
import com.ruoyi.system.domain.agent.AgentResumeCreateRequest;
import com.ruoyi.system.domain.agent.AgentResumeOption;
import com.ruoyi.system.domain.agent.AgentResumeDetail;
import com.ruoyi.system.domain.agent.AgentResumeUpdateRequest;
import org.springframework.web.multipart.MultipartFile;

/**
 * 求职者端简历与投递服务。
 */
public interface IAgentApplicationService
{
    List<AgentResumeOption> selectResumeOptions(Long userId, Long jobId);

    AgentResumeOption createResume(Long userId, AgentResumeCreateRequest request);

    List<AgentResumeOption> selectResumes(Long userId);

    AgentResumeDetail selectResume(Long userId, Long resumeId);

    AgentResumeDetail updateResume(Long userId, Long resumeId, AgentResumeUpdateRequest request);

    AgentResumeDetail uploadResumeFile(Long userId, Long resumeId, MultipartFile file) throws Exception;

    void deleteResume(Long userId, Long resumeId);

    AgentPage<AgentApplication> selectApplications(AgentApplicationQuery query, Long userId);

    AgentApplication selectApplication(Long userId, Long applicationId);

    AgentApplication createApplication(Long userId, AgentApplicationCreateRequest request);
}
