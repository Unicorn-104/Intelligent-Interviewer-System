package com.ruoyi.system.service.app;

import java.util.Map;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentPage;

public interface IAppCompanyService
{
    Map<String, Object> selectCompany(Long userId, Long companyId);

    AgentPage<AgentJob> selectJobs(Long userId, Long companyId, Integer page, Integer size);

    boolean setFollowed(Long userId, Long companyId, boolean followed);

    Map<String, Object> selectFavorites(Long userId, Integer page, Integer size);
}
