package com.ruoyi.enterprise.service.impl;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.TalentPoolMapper;
import com.ruoyi.enterprise.service.ITalentPoolService;
import com.ruoyi.system.mapper.DashboardMapper;

/**
 * 企业端 - 人才库服务实现
 *
 * <p>依据《业务功能分析》UC-03：人才库检索与候选人详情；
 * UC-02 步骤5：完整度检查（比对必填项，计算完整度百分比并标记缺失字段）。</p>
 *
 * @author enterprise
 */
@Service
public class TalentPoolServiceImpl implements ITalentPoolService
{
    @Autowired
    private TalentPoolMapper talentPoolMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Override
    public List<Map<String, Object>> listTalents(Long userId, String keyword, String tag,
            Integer pageNum, Integer pageSize)
    {
        Long companyId = resolveCompanyId(userId);
        PageUtils.startPage(pageNum, pageSize);
        return talentPoolMapper.selectTalentList(companyId, keyword, tag);
    }

    @Override
    public Map<String, Object> getTalentDetail(Long userId, Long talId)
    {
        Map<String, Object> talent = talentPoolMapper.selectTalentById(resolveCompanyId(userId), talId);
        if (talent == null)
        {
            throw new ServiceException("候选人不存在");
        }
        Long resumeId = talent.get("resumeId") == null ? null : Long.valueOf(String.valueOf(talent.get("resumeId")));
        Map<String, Object> result = new LinkedHashMap<>(talent);
        result.put("tags", talentPoolMapper.selectTalentTags(talId));
        if (resumeId != null)
        {
            result.put("educationCount", talentPoolMapper.countEducation(resumeId));
            result.put("workCount", talentPoolMapper.countWork(resumeId));
            result.put("projectCount", talentPoolMapper.countProject(resumeId));
            result.put("skillCount", talentPoolMapper.countSkill(resumeId));
        }
        return result;
    }

    @Override
    public Map<String, Object> getTalentResume(Long userId, Long talId)
    {
        Map<String, Object> talent = talentPoolMapper.selectTalentById(resolveCompanyId(userId), talId);
        if (talent == null)
        {
            throw new ServiceException("候选人不存在");
        }
        Long resumeId = talent.get("resumeId") == null ? null : Long.valueOf(String.valueOf(talent.get("resumeId")));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("talentId", talent.get("talentId"));
        result.put("name", talent.get("name"));
        result.put("phone", talent.get("phone"));
        result.put("email", talent.get("email"));
        result.put("jobDirection", talent.get("jobDirection"));

        List<Map<String, Object>> educationList = new ArrayList<>();
        List<Map<String, Object>> workList = new ArrayList<>();
        List<Map<String, Object>> projectList = new ArrayList<>();
        List<Map<String, Object>> skillList = new ArrayList<>();
        if (resumeId != null)
        {
            educationList = talentPoolMapper.selectEducation(resumeId);
            workList = talentPoolMapper.selectWork(resumeId);
            projectList = talentPoolMapper.selectProject(resumeId);
            skillList = talentPoolMapper.selectSkill(resumeId);
        }
        result.put("educationList", educationList);
        result.put("workList", workList);
        result.put("projectList", projectList);
        result.put("skills", skillList);

        // UC-02 步骤5：完整度检查（标记缺失的关键字段）
        List<String> missingFields = new ArrayList<>();
        if (talent.get("phone") == null || String.valueOf(talent.get("phone")).isEmpty())
        {
            missingFields.add("手机号");
        }
        if (talent.get("email") == null || String.valueOf(talent.get("email")).isEmpty())
        {
            missingFields.add("邮箱");
        }
        if (educationList.isEmpty())
        {
            missingFields.add("教育经历");
        }
        if (workList.isEmpty())
        {
            missingFields.add("工作经历");
        }
        if (skillList.isEmpty())
        {
            missingFields.add("技能标签");
        }
        int filled = 5 - missingFields.size();
        result.put("integrity", filled * 20);
        result.put("missingFields", missingFields);
        return result;
    }

    /** 解析当前用户所属公司（未绑定默认公司1，与 EnterpriseSettingsServiceImpl 一致） */
    private Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }
}
