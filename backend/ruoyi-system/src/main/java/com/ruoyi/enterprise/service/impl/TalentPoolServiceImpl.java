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
import com.ruoyi.enterprise.service.IScreeningService;
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

    @Autowired
    private IScreeningService screeningService;

    @Override
    public List<Map<String, Object>> listTalents(Long userId, String keyword, String tag,
            String direction, Integer archiveSource, Integer status, Integer pageNum, Integer pageSize)
    {
        Long companyId = resolveCompanyId(userId);
        PageUtils.startPage(pageNum, pageSize);
        return talentPoolMapper.selectTalentList(companyId, keyword, tag, direction, archiveSource, status);
    }

    @Override
    public Map<String, Object> getTalentOptions(Long userId)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("directions", talentPoolMapper.selectTalentDirections(companyId));
        result.put("tags", talentPoolMapper.selectTalentTagNames(companyId));
        return result;
    }

    @Override
    public Map<String, Object> archiveTalent(Long userId, Long talId, Boolean archived)
    {
        Map<String, Object> talent = talentPoolMapper.selectTalentById(resolveCompanyId(userId), talId);
        if (talent == null)
        {
            throw new ServiceException("候选人不存在");
        }
        int source = Boolean.TRUE.equals(archived) ? 3 : 0;
        talentPoolMapper.updateArchiveSource(talId, source);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("talentId", talId);
        result.put("archiveSource", source);
        result.put("message", source == 3 ? "已主动归档" : "已取消归档");
        return result;
    }

    @Override
    public Map<String, Object> updateStatus(Long userId, List<Long> talIds, Integer status)
    {
        Long companyId = resolveCompanyId(userId);
        if (talIds == null || talIds.isEmpty())
        {
            throw new ServiceException("请选择候选人");
        }
        if (status == null || status < 0 || status > 9)
        {
            throw new ServiceException("状态值不合法");
        }
        int updated = talentPoolMapper.updateTalentStatus(companyId, talIds, status);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("updated", updated);
        result.put("status", status);
        result.put("message", "已更新 " + updated + " 位候选人的状态");
        return result;
    }

    @Override
    public Map<String, Object> reapplyTalent(Long userId, Long talId, Long positionId)
    {
        Long companyId = resolveCompanyId(userId);
        Map<String, Object> talent = talentPoolMapper.selectTalentById(companyId, talId);
        if (talent == null)
        {
            throw new ServiceException("候选人不存在");
        }
        if (positionId == null)
        {
            throw new ServiceException("请选择转投岗位");
        }
        if (talentPoolMapper.selectPositionInCompany(companyId, positionId) == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        if (talentPoolMapper.selectApplicationExists(talId, positionId) != null)
        {
            throw new ServiceException("该候选人已投递此岗位");
        }
        Long resumeId = talent.get("resumeId") == null ? null : Long.valueOf(String.valueOf(talent.get("resumeId")));
        if (resumeId == null)
        {
            throw new ServiceException("候选人暂无关联简历，无法转投递");
        }
        talentPoolMapper.insertApplication(talId, positionId, resumeId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("talentId", talId);
        result.put("positionId", positionId);
        result.put("message", "已为候选人创建投递记录");
        return result;
    }

    @Override
    public Map<String, Object> careNotify(Long userId, List<Long> talIds, String title, String content)
    {
        Long companyId = resolveCompanyId(userId);
        if (talIds == null || talIds.isEmpty())
        {
            throw new ServiceException("请选择候选人");
        }
        String msgTitle = (title == null || title.trim().isEmpty()) ? "感谢参与，期待再会" : title.trim();
        String msgContent = (content == null || content.trim().isEmpty())
                ? "感谢您对本次招聘的关注，很遗憾本次未能与您携手。您的简历已存入我们的人才库，期待未来有合适的机会再与您联系。"
                : content.trim();
        int sent = 0;
        for (Long talId : talIds)
        {
            Map<String, Object> talent = talentPoolMapper.selectTalentById(companyId, talId);
            if (talent == null)
            {
                continue;
            }
            Long receiverId = talent.get("userId") == null ? null : Long.valueOf(String.valueOf(talent.get("userId")));
            if (receiverId == null)
            {
                continue;
            }
            talentPoolMapper.insertCareMessage(receiverId, msgTitle, msgContent);
            sent++;
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sent", sent);
        result.put("message", "已发送 " + sent + " 条关怀通知");
        return result;
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

    @Override
    public Map<String, Object> getUnscreenedPositions(Long userId)
    {
        Long companyId = resolveCompanyId(userId);
        List<Map<String, Object>> rows = talentPoolMapper.selectUnscreenedPositions(companyId);
        Integer candidateCount = talentPoolMapper.selectUnscreenedCandidateCount(companyId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("rows", rows);
        result.put("positionCount", rows.size());
        result.put("candidateCount", candidateCount == null ? 0 : candidateCount);
        return result;
    }

    @Override
    public List<Map<String, Object>> listUnscreenedApplicants(Long userId, Long positionId, String keyword,
            Integer pageNum, Integer pageSize)
    {
        Long companyId = resolveCompanyId(userId);
        PageUtils.startPage(pageNum, pageSize);
        return talentPoolMapper.selectUnscreenedApplicants(companyId, positionId, keyword);
    }

    @Override
    public Map<String, Object> screenUnscreenedPosition(Long userId, Long positionId)
    {
        if (positionId == null)
        {
            throw new ServiceException("请先选择要初筛的岗位");
        }
        Long companyId = resolveCompanyId(userId);
        if (talentPoolMapper.selectPositionOfCompany(positionId, companyId) == null)
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        return screeningService.screenPendingApplications(positionId);
    }

    /** 解析当前用户所属公司（未绑定默认公司1，与 EnterpriseSettingsServiceImpl 一致） */
    private Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }
}
