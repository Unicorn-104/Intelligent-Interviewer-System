package com.ruoyi.system.service.app.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.app.AppHomeData;
import com.ruoyi.system.domain.app.AppJob;
import com.ruoyi.system.mapper.app.AppJobMapper;
import com.ruoyi.system.service.IEnterpriseJobService;
import com.ruoyi.system.service.app.IAppJobService;

@Service
public class AppJobServiceImpl implements IAppJobService
{
    @Autowired
    private AppJobMapper jobMapper;

    @Autowired
    private IEnterpriseJobService enterpriseJobService;

    @Override
    public AppHomeData selectHomeData(Long userId, String filter)
    {
        List<AppJob> jobs = selectJobs(userId, null, filter, 10);
        AppHomeData data = new AppHomeData();
        data.setNewOpportunityCount(jobs.size());
        data.setHighMatchCount((int) jobs.stream()
                .filter(job -> job.getMatchScore() != null && job.getMatchScore() >= 90)
                .count());
        data.setRecommendations(jobs);
        data.setApplications(jobMapper.selectRecentApplications(userId, 3));
        return data;
    }

    @Override
    public List<AppJob> selectJobs(Long userId, String keyword, String filter, Integer limit)
    {
        int safeLimit = limit == null ? 20 : Math.max(1, Math.min(limit, 50));
        return jobMapper.selectJobs(userId, keyword == null ? null : keyword.trim(), filter, safeLimit);
    }

    @Override
    @Transactional
    public void apply(Long userId, Long positionId)
    { apply(userId, positionId, null); }

    @Override
    @Transactional
    public void apply(Long userId, Long positionId, Long selectedResumeId)
    {
        if (selectedResumeId != null && selectedResumeId <= 0)
            throw new ServiceException("请选择有效简历", 400);
        Long resumeId = selectedResumeId == null ? jobMapper.selectDefaultResumeId(userId)
                : jobMapper.selectOwnedResumeId(userId, selectedResumeId);
        if (selectedResumeId != null && resumeId == null)
            throw new ServiceException("所选简历不存在或不可用，请重新选择", 400);
        if (resumeId == null)
        {
            throw new ServiceException("请先在简历页完善至少一份简历");
        }
        Long companyId = jobMapper.selectCompanyIdByPositionId(positionId);
        if (companyId == null)
        {
            throw new ServiceException("岗位已下线或不存在");
        }
        Long candidateId = jobMapper.selectCandidateId(userId, companyId);
        if (candidateId == null)
        {
            jobMapper.insertCandidate(userId, companyId, resumeId);
            candidateId = jobMapper.selectCandidateId(userId, companyId);
        }
        if (candidateId == null)
        {
            throw new ServiceException("候选人档案创建失败");
        }
        if (jobMapper.countApplication(candidateId, positionId) > 0)
        {
            throw new ServiceException("你已投递过该岗位");
        }
        if (jobMapper.insertApplication(candidateId, positionId, resumeId) <= 0)
        {
            throw new ServiceException("投递失败，请稍后重试");
        }
        // 同步创建投递流程实例，企业端岗位详情/漏斗/筛选均以实例为候选人来源
        enterpriseJobService.ensureProcessInstance(companyId, candidateId, positionId);
    }
}
