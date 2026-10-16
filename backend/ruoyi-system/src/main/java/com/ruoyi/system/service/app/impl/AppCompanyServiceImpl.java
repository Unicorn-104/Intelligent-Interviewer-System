package com.ruoyi.system.service.app.impl;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.Company;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentJobQuery;
import com.ruoyi.system.domain.agent.AgentPage;
import com.ruoyi.system.mapper.app.AppCompanyMapper;
import com.ruoyi.system.service.agent.IAgentJobService;
import com.ruoyi.system.service.app.IAppCompanyService;

@Service
public class AppCompanyServiceImpl implements IAppCompanyService
{
    @Autowired private IAgentJobService jobService;
    @Autowired private AppCompanyMapper companyMapper;

    private Company requireCompany(Long companyId)
    {
        Company company = companyId == null || companyId <= 0 ? null : companyMapper.selectPublicCompany(companyId);
        if (company == null || !Integer.valueOf(1).equals(company.getCmpStatus()))
        {
            throw new ServiceException("企业不存在或已下架", 404);
        }
        return company;
    }

    @Override
    public Map<String, Object> selectCompany(Long userId, Long companyId)
    {
        Company company = requireCompany(companyId);
        // 仅公开招聘展示字段，不返回管理员审核、配额或扩展 JSON。
        Map<String, Object> view = new LinkedHashMap<>();
        view.put("id", company.getCmpId());
        view.put("name", company.getCmpName());
        view.put("logoUrl", company.getCmpLogoUrl());
        view.put("industry", company.getCmpIndustry());
        view.put("size", company.getCmpSize());
        view.put("city", company.getCmpCity());
        view.put("address", company.getCmpAddress());
        view.put("website", company.getCmpWebsite());
        view.put("intro", company.getCmpIntro());
        view.put("verified", Integer.valueOf(1).equals(company.getCmpVerifyStatus()));
        view.put("followed", companyMapper.isFollowed(userId, companyId));
        return view;
    }

    @Override
    public AgentPage<AgentJob> selectJobs(Long userId, Long companyId, Integer page, Integer size)
    {
        requireCompany(companyId);
        AgentJobQuery query = new AgentJobQuery();
        query.setCompanyId(companyId);
        query.setPage(page);
        query.setSize(size);
        return jobService.selectJobs(query, userId);
    }

    @Override
    @Transactional
    public boolean setFollowed(Long userId, Long companyId, boolean followed)
    {
        if (followed)
        {
            requireCompany(companyId);
            companyMapper.follow(userId, companyId);
        }
        else
        {
            companyMapper.unfollow(userId, companyId);
            companyMapper.markNotificationsRead(userId, companyId);
        }
        return companyMapper.isFollowed(userId, companyId);
    }

    @Override
    public Map<String, Object> selectFavorites(Long userId, Integer page, Integer size)
    {
        PageHelper.startPage(page, size);
        List<Long> ids = companyMapper.selectFavoriteCompanyIds(userId);
        PageInfo<Long> info = new PageInfo<>(ids);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("items", ids.stream().map(id -> selectCompany(userId, id)).toList());
        result.put("page", page);
        result.put("size", size);
        result.put("total", info.getTotal());
        result.put("hasNext", (long) page * size < info.getTotal());
        return result;
    }
}
