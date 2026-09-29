package com.ruoyi.system.mapper.agent;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;

/**
 * 求职者端岗位数据访问层。
 */
public interface AgentJobMapper
{
    List<AgentJob> selectJobList(@Param("query") AgentJobQuery query, @Param("userId") Long userId);

    AgentJob selectJobById(@Param("jobId") Long jobId, @Param("userId") Long userId);
}
