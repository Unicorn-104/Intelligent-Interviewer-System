package com.ruoyi.system.service.impl.agent;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.domain.agent.AgentPage;
import com.ruoyi.system.mapper.agent.AgentJobMapper;
import com.ruoyi.system.service.agent.IAgentJobService;

/**
 * 求职者端岗位服务实现。
 */
@Service
public class AgentJobServiceImpl implements IAgentJobService
{
    @Autowired
    private AgentJobMapper jobMapper;

    @Override
    public AgentPage<AgentJob> selectJobs(AgentJobQuery query, Long userId)
    {
        AgentJobQuery normalized = query == null ? new AgentJobQuery() : query;
        normalize(normalized);
        PageHelper.startPage(normalized.getPage(), normalized.getSize());
        List<AgentJob> jobs = jobMapper.selectJobList(normalized, userId);
        PageInfo<AgentJob> pageInfo = new PageInfo<>(jobs);
        pageInfo.getList().forEach(this::decorate);
        return new AgentPage<>(pageInfo.getList(), normalized.getPage(), normalized.getSize(), pageInfo.getTotal());
    }

    @Override
    public List<String> selectJobCategories()
    {
        return jobMapper.selectJobCategories();
    }

    @Override
    public Map<String, Object> selectJobFilterOptions()
    {
        Map<String, Object> options = new LinkedHashMap<>();
        options.put("categories", jobMapper.selectJobCategories());
        options.put("cities", jobMapper.selectJobCities());
        options.put("employmentTypes", jobMapper.selectJobTypes());
        options.put("experiences", jobMapper.selectJobExperiences());
        options.put("educations", jobMapper.selectJobEducations());
        options.put("industries", jobMapper.selectJobIndustries());
        options.put("companySizes", jobMapper.selectJobCompanySizes());
        return options;
    }

    @Override
    public AgentJob selectJob(Long jobId, Long userId)
    {
        if (jobId == null)
        {
            throw new ServiceException("岗位不能为空");
        }
        AgentJob job = jobMapper.selectJobById(jobId, userId);
        if (job == null)
        {
            throw new ServiceException("岗位不存在或已下线");
        }
        decorate(job);
        return job;
    }

    private void normalize(AgentJobQuery query)
    {
        if (query.getPage() == null || query.getPage() < 1)
        {
            query.setPage(1);
        }
        if (query.getSize() == null || query.getSize() < 1)
        {
            query.setSize(10);
        }
        if (query.getSize() > 100)
        {
            query.setSize(100);
        }
        if (StringUtils.isEmpty(query.getSort()))
        {
            query.setSort("latest");
        }
    }

    private void decorate(AgentJob job)
    {
        job.setSalaryText(formatSalary(job.getSalaryMin(), job.getSalaryMax()));
        job.setEducationText(educationText(job.getEducationRequired()));
        job.setJobTypeText(jobTypeText(job.getJobType()));
        job.setStatus(statusKey(job.getStatusCode()));
        job.setStatusText(statusText(job.getStatusCode()));

        JSONObject jd = parseObject(job.getJdJson());
        job.setResponsibilities(toStringList(jd, "responsibilities"));
        job.setRequirements(toStringList(jd, "requirements"));
        if (job.getSkills() == null)
        {
            job.setSkills(Collections.emptyList());
        }
    }

    private JSONObject parseObject(String value)
    {
        if (StringUtils.isEmpty(value))
        {
            return new JSONObject();
        }
        try
        {
            return JSON.parseObject(value);
        }
        catch (RuntimeException ignored)
        {
            return new JSONObject();
        }
    }

    private List<String> toStringList(JSONObject object, String key)
    {
        JSONArray array = object.getJSONArray(key);
        return array == null ? Collections.emptyList() : array.toJavaList(String.class);
    }

    private String formatSalary(BigDecimal min, BigDecimal max)
    {
        if (min == null && max == null)
        {
            return "薪资面议";
        }
        if (min == null)
        {
            return number(max) + "K以上";
        }
        if (max == null)
        {
            return number(min) + "K以下";
        }
        return number(min) + "-" + number(max) + "K";
    }

    private String number(BigDecimal value)
    {
        return value.stripTrailingZeros().toPlainString();
    }

    private String educationText(Integer code)
    {
        if (code == null)
        {
            return "学历不限";
        }
        return switch (code)
        {
            case 1 -> "学历不限";
            case 2 -> "大专";
            case 3 -> "本科";
            case 4 -> "硕士";
            case 5 -> "博士";
            default -> "学历不限";
        };
    }

    private String jobTypeText(Integer code)
    {
        if (code == null)
        {
            return "全职";
        }
        return switch (code)
        {
            case 1 -> "全职";
            case 2 -> "兼职";
            case 3 -> "实习";
            default -> "全职";
        };
    }

    private String statusKey(Integer code)
    {
        return Integer.valueOf(1).equals(code) ? "active" : "paused";
    }

    private String statusText(Integer code)
    {
        return Integer.valueOf(1).equals(code) ? "招聘中" : "暂缓招聘";
    }
}
