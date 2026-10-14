package com.ruoyi.system.service.agent;

import java.util.List;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.domain.agent.AgentPage;

/**
 * 求职者端岗位服务。
 */
public interface IAgentJobService
{
    AgentPage<AgentJob> selectJobs(AgentJobQuery query, Long userId);

    List<String> selectJobCategories();

    AgentJob selectJob(Long jobId, Long userId);
}
