package com.ruoyi.system.service.impl.agent;

import java.math.BigDecimal;
import java.io.IOException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Date;
import java.util.Collections;
import java.util.List;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.agent.AgentApplication;
import com.ruoyi.system.domain.agent.AgentApplicationCreateRequest;
import com.ruoyi.system.domain.agent.AgentApplicationQuery;
import com.ruoyi.system.domain.agent.AgentCandidate;
import com.ruoyi.system.domain.agent.AgentJob;
import com.ruoyi.system.domain.agent.AgentPage;
import com.ruoyi.system.domain.agent.AgentResumeCreateRequest;
import com.ruoyi.system.domain.agent.AgentResumeDetail;
import com.ruoyi.system.domain.agent.AgentResumeEducation;
import com.ruoyi.system.domain.agent.AgentResumeRecord;
import com.ruoyi.system.domain.agent.AgentResumeOption;
import com.ruoyi.system.domain.agent.AgentResumeProject;
import com.ruoyi.system.domain.agent.AgentResumeSkill;
import com.ruoyi.system.domain.agent.AgentTimeline;
import com.ruoyi.system.domain.agent.AgentResumeUpdateRequest;
import com.ruoyi.system.domain.agent.AgentResumeWork;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.mapper.agent.AgentApplicationMapper;
import com.ruoyi.system.mapper.agent.AgentJobMapper;
import com.ruoyi.system.service.agent.IAgentApplicationService;
import com.ruoyi.system.service.app.IAppResumeService;
import com.ruoyi.system.service.app.pdf.ResumePdfParser;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;

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

    @Autowired
    private IAppResumeService appResumeService;

    @Autowired
    private ResumePdfParser pdfParser;

    @Autowired
    private ResumePdfStorage pdfStorage;

    @Override
    public List<AgentResumeOption> selectResumeOptions(Long userId, Long jobId)
    {
        requireActiveJob(jobId, userId);
        return applicationMapper.selectResumeOptions(userId, jobId);
    }

    @Override
    @Transactional
    public AgentResumeOption createResume(Long userId, AgentResumeCreateRequest request)
    {
        if (request == null || StringUtils.isEmpty(request.getResumeName()))
        {
            throw new ServiceException("简历名称不能为空");
        }

        String resumeName = request.getResumeName().trim();
        String jobDirection = StringUtils.isEmpty(request.getJobDirection())
                ? null : request.getJobDirection().trim();
        int activeResumeCount = applicationMapper.countActiveResumes(userId);
        if (activeResumeCount >= 10)
        {
            throw new ServiceException("最多只能创建10份有效简历");
        }
        AgentResumeRecord resume = new AgentResumeRecord();
        resume.setUserId(userId);
        resume.setResumeName(resumeName);
        resume.setJobDirection(jobDirection);
        resume.setIsDefault(activeResumeCount == 0 ? 1 : 0);
        if (applicationMapper.insertResume(resume) <= 0)
        {
            throw new ServiceException("创建简历失败，请稍后重试");
        }

        AgentResumeOption created = applicationMapper.selectResumeById(userId, resume.getId());
        if (created == null)
        {
            throw new ServiceException("简历已创建，但读取简历信息失败");
        }
        return created;
    }

    @Override
    public List<AgentResumeOption> selectResumes(Long userId)
    {
        return applicationMapper.selectResumeList(userId);
    }

    @Override
    public AgentResumeDetail selectResume(Long userId, Long resumeId)
    {
        AgentResumeDetail resume = requireResume(userId, resumeId);
        decorateResume(resume);
        return resume;
    }

    @Override
    @Transactional
    public AgentResumeDetail updateResume(Long userId, Long resumeId, AgentResumeUpdateRequest request)
    {
        if (request == null || StringUtils.isEmpty(request.getResumeName()))
        {
            throw new ServiceException("简历名称不能为空");
        }

        AgentResumeDetail existing = requireResume(userId, resumeId);
        AgentResumeDetail resume = new AgentResumeDetail();
        resume.setId(existing.getId());
        resume.setUserId(userId);
        resume.setResumeName(request.getResumeName().trim());
        resume.setJobDirection(trimToNull(request.getJobDirection()));
        resume.setRealName(trimToNull(request.getRealName()));
        resume.setGender(trimToNull(request.getGender()));
        resume.setWorkStatus(trimToNull(request.getWorkStatus()));
        resume.setCurrentCity(trimToNull(request.getCurrentCity()));
        resume.setPhone(trimToNull(request.getPhone()));
        resume.setEmail(trimToNull(request.getEmail()));
        resume.setTargetRole(trimToNull(request.getTargetRole()));
        resume.setSalaryExpectation(trimToNull(request.getSalaryExpectation()));
        resume.setTargetCity(trimToNull(request.getTargetCity()));
        resume.setArrivalTime(trimToNull(request.getArrivalTime()));

        validateResumeEntries(request);
        if (applicationMapper.updateResumeBase(resume) <= 0)
        {
            throw new ServiceException("保存简历失败，请稍后重试");
        }

        replaceResumeEntries(resumeId, request);
        return selectResume(userId, resumeId);
    }

    @Override
    public AgentResumeDetail parseResumePdf(MultipartFile file) throws Exception
    {
        byte[] bytes = readPdf(file);
        AppResume parsed = appResumeService.parsePdf(bytes, file.getOriginalFilename());
        AgentResumeDetail draft = toAgentResume(parsed);
        if (draft.getEducations().isEmpty() && draft.getWorks().isEmpty()
                && draft.getProjects().isEmpty() && draft.getSkills().isEmpty()
                && StringUtils.isEmpty(draft.getJobDirection()))
        {
            throw new ServiceException("暂未识别到可用的简历信息，请上传更清晰的 PDF");
        }
        draft.setFileName(file.getOriginalFilename());
        draft.setFileSize(file.getSize());
        return draft;
    }

    @Override
    @Transactional
    public AgentResumeDetail createResumeWithPdf(Long userId, AgentResumeUpdateRequest request,
            MultipartFile file) throws Exception
    {
        validateResumeRequest(request);
        byte[] bytes = readPdf(file);
        ResumePdfStorage.StoredPdf stored = pdfStorage.store(userId, bytes, file.getOriginalFilename());
        registerPdfCleanup(userId, stored, null);
        int activeResumeCount = applicationMapper.countActiveResumes(userId);
        if (activeResumeCount >= 10)
        {
            throw new ServiceException("最多只能创建10份有效简历");
        }
        AgentResumeRecord record = new AgentResumeRecord();
        record.setUserId(userId);
        record.setResumeName(request.getResumeName().trim());
        record.setJobDirection(trimToNull(request.getJobDirection()));
        record.setIsDefault(activeResumeCount == 0 ? 1 : 0);
        if (applicationMapper.insertResume(record) <= 0 || record.getId() == null)
        {
            throw new ServiceException("创建简历失败，请稍后重试");
        }
        AgentResumeDetail resume = buildResume(userId, record.getId(), request);
        if (applicationMapper.updateResumeBase(resume) <= 0
                || applicationMapper.updateResumeFile(userId, record.getId(), stored.reference(),
                        stored.name(), stored.size()) <= 0)
        {
            throw new ServiceException("保存简历失败，请稍后重试");
        }
        replaceResumeEntries(record.getId(), request);
        return selectResume(userId, record.getId());
    }

    @Override
    @Transactional
    public AgentResumeDetail updateResumeWithPdf(Long userId, Long resumeId,
            AgentResumeUpdateRequest request, MultipartFile file) throws Exception
    {
        validateResumeRequest(request);
        AgentResumeDetail existing = requireResume(userId, resumeId);
        byte[] bytes = readPdf(file);
        ResumePdfStorage.StoredPdf stored = pdfStorage.store(userId, bytes, file.getOriginalFilename());
        registerPdfCleanup(userId, stored, existing.getFilePath());
        AgentResumeDetail resume = buildResume(userId, resumeId, request);
        if (applicationMapper.updateResumeBase(resume) <= 0
                || applicationMapper.updateResumeFile(userId, resumeId, stored.reference(),
                        stored.name(), stored.size()) <= 0)
        {
            throw new ServiceException("保存简历失败，请稍后重试");
        }
        replaceResumeEntries(resumeId, request);
        return selectResume(userId, resumeId);
    }

    @Override
    public AppResumePdfDocument selectResumePdf(Long userId, Long resumeId)
    {
        AgentResumeDetail resume = requireResume(userId, resumeId);
        if (StringUtils.isEmpty(resume.getFilePath()))
        {
            throw new ServiceException("该简历尚未上传 PDF");
        }
        return new AppResumePdfDocument(pdfStorage.read(userId, resume.getFilePath()), resume.getFileName());
    }
    @Override
    @Transactional
    public AgentResumeDetail uploadResumeFile(Long userId, Long resumeId, MultipartFile file) throws Exception
    {
        AgentResumeDetail existing = requireResume(userId, resumeId);
        byte[] bytes = readPdf(file);
        ResumePdfStorage.StoredPdf stored = pdfStorage.store(userId, bytes, file.getOriginalFilename());
        registerPdfCleanup(userId, stored, existing.getFilePath());
        if (applicationMapper.updateResumeFile(userId, resumeId, stored.reference(),
                stored.name(), stored.size()) <= 0)
        {
            throw new ServiceException("保存简历文件信息失败");
        }
        return selectResume(userId, resumeId);
    }

    @Override
    @Transactional
    public void deleteResume(Long userId, Long resumeId)
    {
        AgentResumeDetail existing = requireResume(userId, resumeId);
        if (applicationMapper.softDeleteResume(userId, resumeId) <= 0)
        {
            throw new ServiceException("删除简历失败，请稍后重试");
        }
        if (Boolean.TRUE.equals(existing.getIsDefault()))
        {
            applicationMapper.promoteFirstActiveResume(userId);
        }
        registerDeletedPdfCleanup(userId, existing.getFilePath());
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

    private byte[] readPdf(MultipartFile file) throws IOException
    {
        if (file == null || file.isEmpty())
        {
            throw new ServiceException("请选择 PDF 简历文件");
        }
        String originalFilename = file.getOriginalFilename();
        if (StringUtils.isEmpty(originalFilename) || !originalFilename.toLowerCase().endsWith(".pdf"))
        {
            throw new ServiceException("仅支持 PDF 格式的简历文件");
        }
        if (file.getSize() > 10 * 1024 * 1024L)
        {
            throw new ServiceException("简历文件不能超过10MB");
        }
        byte[] bytes = file.getBytes();
        pdfParser.validate(bytes);
        return bytes;
    }

    private void validateResumeRequest(AgentResumeUpdateRequest request)
    {
        if (request == null || StringUtils.isEmpty(request.getResumeName()))
        {
            throw new ServiceException("简历名称不能为空");
        }
        validateResumeEntries(request);
    }

    private AgentResumeDetail buildResume(Long userId, Long resumeId, AgentResumeUpdateRequest request)
    {
        AgentResumeDetail resume = new AgentResumeDetail();
        resume.setId(resumeId);
        resume.setUserId(userId);
        resume.setResumeName(request.getResumeName().trim());
        resume.setJobDirection(trimToNull(request.getJobDirection()));
        resume.setRealName(trimToNull(request.getRealName()));
        resume.setGender(trimToNull(request.getGender()));
        resume.setWorkStatus(trimToNull(request.getWorkStatus()));
        resume.setCurrentCity(trimToNull(request.getCurrentCity()));
        resume.setPhone(trimToNull(request.getPhone()));
        resume.setEmail(trimToNull(request.getEmail()));
        resume.setTargetRole(trimToNull(request.getTargetRole()));
        resume.setSalaryExpectation(trimToNull(request.getSalaryExpectation()));
        resume.setTargetCity(trimToNull(request.getTargetCity()));
        resume.setArrivalTime(trimToNull(request.getArrivalTime()));
        return resume;
    }

    private AgentResumeDetail toAgentResume(AppResume source)
    {
        AgentResumeDetail target = new AgentResumeDetail();
        target.setResumeName(source.getResumeName());
        target.setJobDirection(source.getJobDirection());
        target.setStructureMethod(source.getStructureMethod());
        target.setParseMethod(source.getParseMethod());
        target.setUnmappedText(source.getUnmappedText());
        target.setParseWarnings(source.getParseWarnings());
        for (AppResume.Education item : source.getEducations())
        {
            AgentResumeEducation education = new AgentResumeEducation();
            education.setSchool(item.getSchool());
            education.setMajor(item.getMajor());
            education.setDegree(item.getDegree());
            education.setGpa(item.getGpa());
            education.setStartDate(toDate(item.getStartDate()));
            education.setEndDate(toDate(item.getEndDate()));
            education.setDescription(item.getDescription());
            target.getEducations().add(education);
        }
        for (AppResume.Work item : source.getWorks())
        {
            AgentResumeWork work = new AgentResumeWork();
            work.setCompany(item.getCompany());
            work.setPosition(item.getPosition());
            work.setDepartment(item.getDepartment());
            work.setStartDate(toDate(item.getStartDate()));
            work.setEndDate(toDate(item.getEndDate()));
            work.setCurrent(item.getCurrent());
            work.setSalaryRange(item.getSalaryRange());
            work.setDescription(item.getDescription());
            target.getWorks().add(work);
        }
        for (AppResume.Project item : source.getProjects())
        {
            AgentResumeProject project = new AgentResumeProject();
            project.setName(item.getName());
            project.setRole(item.getRole());
            project.setStartDate(toDate(item.getStartDate()));
            project.setEndDate(toDate(item.getEndDate()));
            project.setDescription(item.getDescription());
            project.setTechStack(item.getTechStack());
            target.getProjects().add(project);
        }
        for (AppResume.Skill item : source.getSkills())
        {
            AgentResumeSkill skill = new AgentResumeSkill();
            skill.setName(item.getName());
            skill.setLevel(item.getLevel());
            target.getSkills().add(skill);
        }
        return target;
    }

    private Date toDate(LocalDate value)
    {
        return value == null ? null : java.sql.Date.valueOf(value);
    }

    private void registerPdfCleanup(Long userId, ResumePdfStorage.StoredPdf stored, String previousReference)
    {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization()
        {
            @Override
            public void afterCompletion(int status)
            {
                if (status != STATUS_COMMITTED)
                {
                    pdfStorage.delete(userId, stored.reference());
                }
                else if (StringUtils.isNotEmpty(previousReference))
                {
                    pdfStorage.delete(userId, previousReference);
                }
            }
        });
    }

    private void registerDeletedPdfCleanup(Long userId, String reference)
    {
        if (StringUtils.isEmpty(reference))
        {
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization()
        {
            @Override
            public void afterCompletion(int status)
            {
                if (status == STATUS_COMMITTED)
                {
                    pdfStorage.delete(userId, reference);
                }
            }
        });
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

    private AgentResumeDetail requireResume(Long userId, Long resumeId)
    {
        if (resumeId == null)
        {
            throw new ServiceException("简历不能为空");
        }
        AgentResumeDetail resume = applicationMapper.selectResumeDetail(userId, resumeId);
        if (resume == null)
        {
            throw new ServiceException("简历不存在、已停用或不属于当前用户");
        }
        return resume;
    }

    private void decorateResume(AgentResumeDetail resume)
    {
        if (StringUtils.isNotEmpty(resume.getFilePath()))
        {
            resume.setFileUrl("/agent/v1/resumes/" + resume.getId() + "/file");
        }
    }

    private void validateResumeEntries(AgentResumeUpdateRequest request)
    {
        if (sizeOf(request.getEducations()) > 20 || sizeOf(request.getWorks()) > 20
                || sizeOf(request.getProjects()) > 20 || sizeOf(request.getSkills()) > 30)
        {
            throw new ServiceException("简历经历或技能数量超出限制");
        }
        for (AgentResumeEducation education : safeList(request.getEducations()))
        {
            if (StringUtils.isEmpty(education.getSchool()))
            {
                throw new ServiceException("教育经历的学校不能为空");
            }
        }
        for (AgentResumeWork work : safeList(request.getWorks()))
        {
            if (StringUtils.isEmpty(work.getCompany()) || StringUtils.isEmpty(work.getPosition()))
            {
                throw new ServiceException("工作经历的公司和职位不能为空");
            }
        }
        for (AgentResumeProject project : safeList(request.getProjects()))
        {
            if (StringUtils.isEmpty(project.getName()))
            {
                throw new ServiceException("项目经历名称不能为空");
            }
        }
        for (AgentResumeSkill skill : safeList(request.getSkills()))
        {
            if (StringUtils.isEmpty(skill.getName()))
            {
                throw new ServiceException("技能名称不能为空");
            }
        }
    }

    private void replaceResumeEntries(Long resumeId, AgentResumeUpdateRequest request)
    {
        applicationMapper.deleteResumeEducation(resumeId);
        applicationMapper.deleteResumeWork(resumeId);
        applicationMapper.deleteResumeProject(resumeId);
        applicationMapper.deleteResumeSkill(resumeId);

        for (AgentResumeEducation education : safeList(request.getEducations()))
        {
            education.setResumeId(resumeId);
            applicationMapper.insertResumeEducation(education);
        }
        for (AgentResumeWork work : safeList(request.getWorks()))
        {
            work.setResumeId(resumeId);
            applicationMapper.insertResumeWork(work);
        }
        for (AgentResumeProject project : safeList(request.getProjects()))
        {
            project.setResumeId(resumeId);
            applicationMapper.insertResumeProject(project);
        }
        for (AgentResumeSkill skill : safeList(request.getSkills()))
        {
            skill.setResumeId(resumeId);
            if (skill.getLevel() == null)
            {
                skill.setLevel(2);
            }
            applicationMapper.insertResumeSkill(skill);
        }
    }

    private <T> List<T> safeList(List<T> value)
    {
        return value == null ? Collections.emptyList() : value;
    }

    private int sizeOf(List<?> value)
    {
        return value == null ? 0 : value.size();
    }

    private String trimToNull(String value)
    {
        if (StringUtils.isEmpty(value))
        {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
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
