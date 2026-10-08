package com.ruoyi.system.service.agent;

import java.util.List;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.domain.agent.AgentApplicationCreateRequest;
import com.ruoyi.system.domain.agent.AgentApplicationQuery;
import com.ruoyi.system.domain.agent.AgentPage;
import com.ruoyi.system.domain.agent.AgentResumeCreateRequest;
import com.ruoyi.system.domain.agent.AgentResumeOption;

/**
 * 求职者端简历与投递服务。
 */
public interface IAgentApplicationService
{
    List<AgentResumeOption> selectResumeOptions(Long userId, Long jobId);

    AgentResumeOption createResume(Long userId, AgentResumeCreateRequest request);

    AgentPage<AgentApplication> selectApplications(AgentApplicationQuery query, Long userId);

    AgentApplication selectApplication(Long userId, Long applicationId);

    AgentApplication createApplication(Long userId, AgentApplicationCreateRequest request);
}
