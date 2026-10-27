package com.ruoyi.enterprise.service.impl;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.TalentPoolMapper;
import com.ruoyi.enterprise.service.IScreeningService;
import com.ruoyi.enterprise.service.ITalentPoolService;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.app.AppResumeMapper;
import com.ruoyi.system.service.IEnterpriseJobService;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;

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

    @Autowired
    private IEnterpriseJobService enterpriseJobService;

    @Autowired
    private AppResumeMapper appResumeMapper;

    @Autowired
    private ResumePdfStorage resumePdfStorage;

    @Override
    public List<Map<String, Object>> listTalents(Long userId, String keyword, String tag,
            String direction, Integer archiveSource, Integer status, Integer pageNum, Integer pageSize)
    {
        return listTalents(userId, keyword, tag, direction, archiveSource, status, pageNum, pageSize,
                new TalentSearchCriteria());
    }

    @Override
    public List<Map<String, Object>> listTalents(Long userId, String keyword, String tag,
            String direction, Integer archiveSource, Integer status, Integer pageNum, Integer pageSize,
            TalentSearchCriteria criteria)
    {
        PageUtils.clearPage();
        if (criteria == null) criteria = new TalentSearchCriteria();
        criteria.validate();
        if (status != null && (status < 0 || status > 9)) throw new ServiceException("招聘状态不合法");
        if (archiveSource != null && (archiveSource < 0 || archiveSource > 4)) throw new ServiceException("归档来源不合法");
        if (pageNum == null || pageNum < 1 || pageSize == null || pageSize < 1 || pageSize > 100)
            throw new ServiceException("分页参数不合法");
        Long companyId = requireSearchCompany(userId);
        PageUtils.startPage(pageNum, pageSize);
        try
        {
            return talentPoolMapper.selectFilteredTalentList(companyId, keyword, tag, direction,
                    archiveSource, status, criteria);
        }
        finally { PageUtils.clearPage(); }
    }

    private Long requireSearchCompany(Long userId)
    {
        PageUtils.clearPage();
        if (userId == null) throw new ServiceException("登录已失效");
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        if (companyId == null) throw new ServiceException("当前账号未绑定企业");
        return companyId;
    }

    @Override
    public Map<String, Object> getTalentOptions(Long userId)
    {
        Long companyId = requireSearchCompany(userId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("searchFilterVersion", 2);
        result.put("currentCities", talentPoolMapper.selectTalentCities(companyId, "current"));
        result.put("targetCities", talentPoolMapper.selectTalentCities(companyId, "target"));
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
    public Map<String, Object> batchTags(Long userId, List<Long> talIds, String tagName, Integer source)
    {
        Long companyId = resolveCompanyId(userId);
        if (talIds == null || talIds.isEmpty())
        {
            throw new ServiceException("请选择候选人");
        }
        if (tagName == null || tagName.trim().isEmpty())
        {
            throw new ServiceException("请填写标签名称");
        }
        int inserted = talentPoolMapper.insertBatchTags(companyId, talIds, tagName.trim(),
                source == null ? 1 : source);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("inserted", inserted);
        result.put("tagName", tagName.trim());
        result.put("message", "已为 " + inserted + " 位候选人添加标签「" + tagName.trim() + "」");
        return result;
    }

    @Override
    @Transactional
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
        // 与求职者自主投递一致，同步创建流程实例供企业端岗位详情/漏斗/筛选使用
        enterpriseJobService.ensureProcessInstance(companyId, talId, positionId);
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
        result.put("fileName", resumeFileName(resumeId));
        return result;
    }

    @Override
    public AppResumePdfDocument getTalentResumePdf(Long userId, Long talId)
    {
        Map<String, Object> talent = talentPoolMapper.selectTalentById(resolveCompanyId(userId), talId);
        if (talent == null)
        {
            throw new ServiceException("候选人不存在");
        }
        Long resumeId = talent.get("resumeId") == null ? null
                : Long.valueOf(String.valueOf(talent.get("resumeId")));
        if (resumeId == null)
        {
            throw new ServiceException("该候选人暂无关联简历");
        }
        Long candidateUserId = talent.get("userId") == null ? null
                : Long.valueOf(String.valueOf(talent.get("userId")));
        if (candidateUserId == null || candidateUserId <= 0)
        {
            throw new ServiceException("候选人账号无效，无法读取原始简历");
        }
        // 不带用户条件的查询仅限此处：已先校验候选人归属本企业，再校验简历归属候选人本人
        AppResume resume = appResumeMapper.selectResumeById(resumeId);
        if (resume == null || !candidateUserId.equals(resume.getUserId()))
        {
            throw new ServiceException("简历不存在或无权访问");
        }
        if (resume.getFilePath() == null || resume.getFilePath().isBlank())
        {
            throw new ServiceException("该简历未保存原始 PDF");
        }
        return new AppResumePdfDocument(resumePdfStorage.read(candidateUserId, resume.getFilePath()),
                resume.getFileName());
    }

    /** 读取简历原始附件文件名；无附件或简历不可用时返回 null，不影响结构化数据展示。 */
    private String resumeFileName(Long resumeId)
    {
        if (resumeId == null)
        {
            return null;
        }
        AppResume resume = appResumeMapper.selectResumeById(resumeId);
        return resume == null || resume.getFilePath() == null || resume.getFilePath().isBlank()
                || resume.getFileName() == null || resume.getFileName().isBlank()
                ? null : resume.getFileName();
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
