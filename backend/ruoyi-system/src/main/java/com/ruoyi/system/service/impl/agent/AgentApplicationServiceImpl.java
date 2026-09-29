package com.ruoyi.system.service.impl.agent;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.domain.agent.AgentApplicationCreateRequest;
import com.ruoyi.system.domain.agent.AgentApplicationQuery;
import com.ruoyi.system.domain.agent.AgentCandidate;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentPage;
import com.ruoyi.system.domain.agent.AgentResumeOption;
import com.ruoyi.system.domain.agent.AgentTimeline;
import com.ruoyi.system.mapper.agent.AgentApplicationMapper;
import com.ruoyi.system.mapper.agent.AgentJobMapper;
import com.ruoyi.system.service.agent.IAgentApplicationService;

/**
 * 求职者端简历与投递服务实现。
 */
@Service
public class AgentApplicationServiceImpl implements IAgentApplicationService
{
    @Autowired
    private AgentApplicationMapper applicationMapper;

    @Autowired
    private AgentJobMapper jobMapper;

    @Override
    public List<AgentResumeOption> selectResumeOptions(Long userId, Long jobId)
    {
        requireActiveJob(jobId, userId);
        return applicationMapper.selectResumeOptions(userId, jobId);
    }

    @Override
    public AgentPage<AgentApplication> selectApplications(AgentApplicationQuery query, Long userId)
    {
        AgentApplicationQuery normalized = query == null ? new AgentApplicationQuery() : query;
        normalize(normalized);
        PageHelper.startPage(normalized.getPage(), normalized.getSize());
        List<AgentApplication> applications = applicationMapper.selectApplicationList(userId, normalized.getStatus());
        PageInfo<AgentApplication> pageInfo = new PageInfo<>(applications);
        pageInfo.getList().forEach(this::decorate);
        return new AgentPage<>(pageInfo.getList(), normalized.getPage(), normalized.getSize(), pageInfo.getTotal());
    }

    @Override
    public AgentApplication selectApplication(Long userId, Long applicationId)
    {
        if (applicationId == null)
        {
            throw new ServiceException("投递记录不能为空");
        }
        AgentApplication application = applicationMapper.selectApplicationById(userId, applicationId);
        if (application == null)
        {
            throw new ServiceException("投递记录不存在或无权访问");
        }
        decorate(application);
        List<AgentTimeline> timeline = new ArrayList<>();
        timeline.add(new AgentTimeline("submitted", "done", "已投递", "简历已提交，等待企业处理",
                application.getAppliedAt() == null ? new Date() : application.getAppliedAt()));
        List<AgentTimeline> statusTimeline = applicationMapper.selectTimeline(application.getCandidateId(),
                application.getAppliedAt());
        if (statusTimeline != null)
        {
            timeline.addAll(statusTimeline);
        }
        application.setTimeline(timeline);
        return application;
    }

    @Override
    @Transactional
    public AgentApplication createApplication(Long userId, AgentApplicationCreateRequest request)
    {
        if (request == null || request.getJobId() == null || request.getResumeId() == null)
        {
            throw new ServiceException("岗位和简历不能为空");
        }
        if (StringUtils.isEmpty(request.getConsentVersion()))
        {
            throw new ServiceException("请先确认投递协议");
        }

        AgentJob job = requireActiveJob(request.getJobId(), userId);
        AgentResumeOption selectedResume = findResume(userId, request.getJobId(), request.getResumeId());
        if (selectedResume == null)
        {
            throw new ServiceException("简历不存在、已停用或不属于当前用户");
        }

        AgentApplication existing = applicationMapper.selectExistingApplication(userId, request.getJobId());
        if (existing != null)
        {
            decorate(existing);
            existing.setDuplicate(Boolean.TRUE);
            return existing;
        }

        Long candidateId = applicationMapper.selectCandidateId(userId, job.getCompanyId());
        if (candidateId == null)
        {
            AgentCandidate candidate = new AgentCandidate();
            candidate.setUserId(userId);
            candidate.setCompanyId(job.getCompanyId());
            candidate.setResumeId(request.getResumeId());
            applicationMapper.insertCandidate(candidate);
            candidateId = candidate.getCandidateId();
        }
        else
        {
            applicationMapper.updateCandidateResume(candidateId, userId, job.getCompanyId(), request.getResumeId());
        }
        if (candidateId == null)
        {
            throw new ServiceException("创建人才档案失败");
        }

        AgentApplication application = new AgentApplication();
        application.setCandidateId(candidateId);
        application.setJobId(job.getId());
        application.setResumeId(request.getResumeId());
        application.setMatchedScore(toBigDecimal(selectedResume.getMatchScore()));
        if (applicationMapper.insertApplication(application) <= 0)
        {
            throw new ServiceException("投递失败，请稍后重试");
        }
        AgentApplication created = applicationMapper.selectApplicationById(userId, application.getId());
        if (created == null)
        {
            throw new ServiceException("投递已提交，但读取投递记录失败");
        }
        decorate(created);
        created.setDuplicate(Boolean.FALSE);
        return created;
    }

    private AgentJob requireActiveJob(Long jobId, Long userId)
    {
        AgentJob job = jobMapper.selectJobById(jobId, userId);
        if (job == null)
        {
            throw new ServiceException("岗位不存在或已下线");
        }
        if (!Integer.valueOf(1).equals(job.getStatusCode()))
        {
            throw new ServiceException("岗位当前暂停招聘，暂不能投递");
        }
        return job;
    }

    private AgentResumeOption findResume(Long userId, Long jobId, Long resumeId)
    {
        return applicationMapper.selectResumeOptions(userId, jobId).stream()
                .filter(item -> resumeId.equals(item.getId()))
                .findFirst()
                .orElse(null);
    }

    private void normalize(AgentApplicationQuery query)
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
        if (StringUtils.isNotEmpty(query.getStatus())
                && !List.of("active", "interview", "closed").contains(query.getStatus()))
        {
            throw new ServiceException("非法投递状态筛选");
        }
    }

    private void decorate(AgentApplication application)
    {
        application.setSalaryText(formatSalary(application.getSalaryMin(), application.getSalaryMax()));
        Integer statusCode = application.getStatusCode();
        application.setStatus(statusKey(statusCode));
        application.setStatusText(statusText(statusCode));
    }

    private BigDecimal toBigDecimal(Integer value)
    {
        return value == null ? null : BigDecimal.valueOf(value);
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

    private String statusKey(Integer code)
    {
        if (code == null)
        {
            return "pending";
        }
        return switch (code)
        {
            case 3, 5, 6 -> "interview";
            case 2, 7, 8 -> "closed";
            default -> "active";
        };
    }

    private String statusText(Integer code)
    {
        if (code == null)
        {
            return "待处理";
        }
        return switch (code)
        {
            case 0 -> "待处理";
            case 1 -> "初筛通过";
            case 2 -> "初筛淘汰";
            case 3 -> "已约面";
            case 4 -> "待笔试";
            case 5 -> "笔试中";
            case 6 -> "笔试通过";
            case 7 -> "笔试未通过";
            case 8 -> "笔试缺考";
            default -> "投递处理中";
        };
    }
}
