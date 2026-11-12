package com.ruoyi.enterprise.service;

import java.io.IOException;
import java.io.InputStream;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.domain.EntResumeSnapshot;
import com.ruoyi.enterprise.mapper.EntResumeSnapshotMapper;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.mapper.app.AppResumeMapper;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;
import com.ruoyi.system.service.storage.S3FileStorage;

/**
 * 企业投递快照创建服务。
 *
 * <p>在投递事务内：行锁源简历保证一致性读取，复制 PDF 为企业独立不可变对象，
 * 复制完整结构化内容生成快照；事务回滚时清理已写企业文件。同一投递重复调用幂等。</p>
 */
@Service
public class EntResumeSnapshotService
{
    private static final int MAX_PDF_BYTES = 10 * 1024 * 1024;

    /** 简历条目时间统一输出到「年-月」，与人才库 TalentPoolMapper 子表口径保持一致 */
    private static final DateTimeFormatter MONTH_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM");

    private final EntResumeSnapshotMapper snapshotMapper;
    private final AppResumeMapper appResumeMapper;
    private final ResumePdfStorage resumePdfStorage;
    private final EnterpriseResumeStorage enterpriseStorage;

    public EntResumeSnapshotService(EntResumeSnapshotMapper snapshotMapper,
            AppResumeMapper appResumeMapper, ResumePdfStorage resumePdfStorage,
            EnterpriseResumeStorage enterpriseStorage)
    {
        this.snapshotMapper = snapshotMapper;
        this.appResumeMapper = appResumeMapper;
        this.resumePdfStorage = resumePdfStorage;
        this.enterpriseStorage = enterpriseStorage;
    }

    /**
     * 为一次投递创建企业快照。
     *
     * @param appId 投递ID
     * @param userId 求职者用户ID（用于行锁与读取源 PDF）
     * @param candidateId 候选人ID
     * @param companyId 企业ID
     * @param positionId 岗位ID
     * @param sourceResumeId 源 C-App 简历ID
     */
    @Transactional
    public EntResumeSnapshot createForApplication(Long appId, Long userId, Long candidateId,
            Long companyId, Long positionId, Long sourceResumeId)
    {
        // 幂等：已有快照直接返回，不重复生成文件
        EntResumeSnapshot existing = snapshotMapper.selectByAppId(appId);
        if (existing != null) return existing;

        // 一致性读取：行锁源简历主表，防止投递期间被修改
        AppResume source = appResumeMapper.selectResumeForUpdate(sourceResumeId, userId);
        if (source == null) throw new ServiceException("简历不存在、已停用或无权访问");

        // 同一行锁保护下读取结构化子表，确保与主表来自同一版本
        List<AppResume.Education> srcEdu = appResumeMapper.selectEducations(sourceResumeId);
        List<AppResume.Work> srcWork = appResumeMapper.selectWorks(sourceResumeId);
        List<AppResume.Project> srcPrj = appResumeMapper.selectProjects(sourceResumeId);
        List<AppResume.Skill> srcSkl = appResumeMapper.selectSkills(sourceResumeId);

        String fileName = source.getFileName();

        // 先转换结构化子表（自增主键不参与哈希），供全内容哈希与落库复用
        List<EntResumeSnapshot.Education> educations = toEntEducations(srcEdu);
        List<EntResumeSnapshot.Work> works = toEntWorks(srcWork);
        List<EntResumeSnapshot.Project> projects = toEntProjects(srcPrj);
        List<EntResumeSnapshot.Skill> skills = toEntSkills(srcSkl);

        // 读取源 PDF 并复制为企业独立对象；pdfBytes 同时参与全内容哈希
        String companyFileRef = null;
        Long fileSize = null;
        byte[] pdfBytes = null;
        if (source.getFilePath() != null && !source.getFilePath().isBlank())
        {
            pdfBytes = readSourcePdf(userId, source.getFilePath());
            EnterpriseResumeStorage.StoredPdf stored =
                    enterpriseStorage.store(companyId, appId, pdfBytes, fileName);
            companyFileRef = stored.reference();
            fileSize = stored.size();
            // 事务回滚则清理企业文件，避免孤儿对象
            registerRollbackCleanup(companyFileRef);
        }

        EntResumeSnapshot snapshot = new EntResumeSnapshot();
        snapshot.setAppId(appId);
        snapshot.setCandidateId(candidateId);
        snapshot.setCompanyId(companyId);
        snapshot.setPositionId(positionId);
        snapshot.setSourceResumeId(sourceResumeId);
        snapshot.setResumeName(source.getResumeName());
        snapshot.setJobDirection(source.getJobDirection());
        snapshot.setFilePath(companyFileRef);
        snapshot.setFileName(fileName);
        snapshot.setFileSize(fileSize);
        snapshot.setSnapshotStatus(EntResumeSnapshot.STATUS_COMPLETE);
        // 实时投递在源简历行锁下读取，天然为投递原件
        snapshot.setVersionVerified(EntResumeSnapshot.VERSION_LIVE_ORIGINAL);
        // 实时投递时间为真实快照时刻，标记 LIVE_REAL
        snapshot.setTimeSource(EntResumeSnapshot.TIME_LIVE_REAL);
        snapshot.setSnapshotAt(LocalDateTime.now());
        snapshot.setEducations(educations);
        snapshot.setWorks(works);
        snapshot.setProjects(projects);
        snapshot.setSkills(skills);
        // 全内容哈希（v2）：覆盖 PDF 字节 + 简历名/方向 + 四子表规范化内容
        snapshot.setContentHash(ResumeContentHasher.hash(snapshot, pdfBytes));
        snapshotMapper.insertSnapshot(snapshot);

        if (!educations.isEmpty()) snapshotMapper.insertEducationList(snapshot.getId(), educations);
        if (!works.isEmpty()) snapshotMapper.insertWorkList(snapshot.getId(), works);
        if (!projects.isEmpty()) snapshotMapper.insertProjectList(snapshot.getId(), projects);
        if (!skills.isEmpty()) snapshotMapper.insertSkillList(snapshot.getId(), skills);

        return snapshotMapper.selectById(snapshot.getId());
    }

    /**
     * 投递级结构化简历视图（企业端只读）。
     *
     * <p>以 applicationId 唯一定位：先做企业归属校验，再读取企业快照并转换为前端兼容结构；
     * 快照不存在时抛 SNAPSHOT_NOT_AVAILABLE，不回退 C-App 当前简历。</p>
     *
     * @param companyId 当前登录企业ID
     * @param applicationId 投递ID
     */
    public Map<String, Object> getApplicationResumeView(Long companyId, Long applicationId)
    {
        requireOwnership(companyId, applicationId);
        EntResumeSnapshot snapshot = snapshotMapper.selectByAppId(applicationId);
        if (snapshot == null)
        {
            throw new ServiceException("该投递暂无企业简历快照（SNAPSHOT_NOT_AVAILABLE）",
                    S3FileStorage.NOT_FOUND_CODE);
        }
        return toResumeView(snapshot);
    }

    /**
     * 投递级原始简历 PDF（企业端只读）。
     *
     * <p>读取企业独立命名空间文件，不依赖 rbs_status、不读 C-App 私有 PDF；
     * 路径为空或对象缺失分别给出明确提示，不影响结构化简历展示。</p>
     */
    public AppResumePdfDocument getApplicationResumePdf(Long companyId, Long applicationId)
    {
        requireOwnership(companyId, applicationId);
        EntResumeSnapshot snapshot = snapshotMapper.selectByAppId(applicationId);
        if (snapshot == null)
        {
            throw new ServiceException("该投递暂无企业简历快照（SNAPSHOT_NOT_AVAILABLE）",
                    S3FileStorage.NOT_FOUND_CODE);
        }
        if (snapshot.getFilePath() == null || snapshot.getFilePath().isBlank())
        {
            throw new ServiceException("该投递原始 PDF 不可用");
        }
        Resource resource;
        try
        {
            resource = enterpriseStorage.read(snapshot.getFilePath());
        }
        catch (ServiceException error)
        {
            // 企业对象缺失：明确提示文件缺失，不回退读取 C-App 当前 PDF；getCode 可能为 null，用常量反向比较避免拆箱空指针
            if (Integer.valueOf(S3FileStorage.NOT_FOUND_CODE).equals(error.getCode()))
            {
                throw new ServiceException("原始简历文件缺失，请联系管理员核实",
                        S3FileStorage.NOT_FOUND_CODE);
            }
            throw error;
        }
        return new AppResumePdfDocument(resource, snapshot.getFileName());
    }

    /** 投递企业归属校验：不属于当前企业或投递不存在一律拒绝，不暴露投递是否真实存在。 */
    private void requireOwnership(Long companyId, Long applicationId)
    {
        if (companyId == null || applicationId == null || applicationId <= 0)
        {
            throw new ServiceException("投递标识无效");
        }
        Map<String, Object> ownership =
                snapshotMapper.selectApplicationOwnership(applicationId, companyId);
        if (ownership == null)
        {
            throw new ServiceException("无权访问该投递或投递不存在");
        }
    }

    private byte[] readSourcePdf(Long userId, String reference)
    {
        try (InputStream input = resumePdfStorage.readResource(userId, reference).getInputStream())
        {
            byte[] bytes = input.readNBytes(MAX_PDF_BYTES + 1);
            if (bytes.length > MAX_PDF_BYTES) throw new ServiceException("原始简历过大");
            return bytes;
        }
        catch (IOException error)
        {
            throw new ServiceException("读取投递简历 PDF 失败，请稍后重试");
        }
    }

    private void registerRollbackCleanup(String reference)
    {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization()
        {
            @Override
            public void afterCompletion(int status)
            {
                if (status != STATUS_COMMITTED) enterpriseStorage.delete(reference);
            }
        });
    }

    private List<EntResumeSnapshot.Education> toEntEducations(List<AppResume.Education> source)
    {
        List<EntResumeSnapshot.Education> result = new ArrayList<>();
        for (AppResume.Education item : source)
        {
            EntResumeSnapshot.Education target = new EntResumeSnapshot.Education();
            target.setSchool(item.getSchool());
            target.setMajor(item.getMajor());
            target.setDegree(item.getDegree());
            target.setStartDate(item.getStartDate());
            target.setEndDate(item.getEndDate());
            target.setGpa(item.getGpa());
            target.setDescription(item.getDescription());
            result.add(target);
        }
        return result;
    }

    private List<EntResumeSnapshot.Work> toEntWorks(List<AppResume.Work> source)
    {
        List<EntResumeSnapshot.Work> result = new ArrayList<>();
        for (AppResume.Work item : source)
        {
            EntResumeSnapshot.Work target = new EntResumeSnapshot.Work();
            target.setCompany(item.getCompany());
            target.setPosition(item.getPosition());
            target.setDepartment(item.getDepartment());
            target.setStartDate(item.getStartDate());
            target.setEndDate(item.getEndDate());
            target.setCurrent(item.getCurrent());
            target.setSalaryRange(item.getSalaryRange());
            target.setDescription(item.getDescription());
            result.add(target);
        }
        return result;
    }

    private List<EntResumeSnapshot.Project> toEntProjects(List<AppResume.Project> source)
    {
        List<EntResumeSnapshot.Project> result = new ArrayList<>();
        for (AppResume.Project item : source)
        {
            EntResumeSnapshot.Project target = new EntResumeSnapshot.Project();
            target.setName(item.getName());
            target.setRole(item.getRole());
            target.setStartDate(item.getStartDate());
            target.setEndDate(item.getEndDate());
            target.setDescription(item.getDescription());
            target.setTechStack(item.getTechStack());
            result.add(target);
        }
        return result;
    }

    private List<EntResumeSnapshot.Skill> toEntSkills(List<AppResume.Skill> source)
    {
        List<EntResumeSnapshot.Skill> result = new ArrayList<>();
        for (AppResume.Skill item : source)
        {
            EntResumeSnapshot.Skill target = new EntResumeSnapshot.Skill();
            target.setName(item.getName());
            target.setLevel(item.getLevel());
            result.add(target);
        }
        return result;
    }

    /**
     * 将企业快照转换为前端 TalentResumeSection 兼容的视图结构。
     * 字段名与人才库 getTalentResume 返回口径对齐，前端无需维护两套字段。
     */
    private Map<String, Object> toResumeView(EntResumeSnapshot snapshot)
    {
        List<Map<String, Object>> educationList = new ArrayList<>();
        for (EntResumeSnapshot.Education item : snapshot.getEducations())
        {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("school", item.getSchool());
            row.put("major", item.getMajor());
            row.put("degree", item.getDegree());
            row.put("startDate", formatMonth(item.getStartDate()));
            row.put("endDate", formatMonth(item.getEndDate()));
            educationList.add(row);
        }

        List<Map<String, Object>> workList = new ArrayList<>();
        for (EntResumeSnapshot.Work item : snapshot.getWorks())
        {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("company", item.getCompany());
            row.put("position", item.getPosition());
            row.put("startDate", formatMonth(item.getStartDate()));
            // 在职工作结束时间显示「至今」，与人才库 selectWork 口径一致
            row.put("endDate", Boolean.TRUE.equals(item.getCurrent())
                    ? "至今" : formatMonth(item.getEndDate()));
            row.put("summary", item.getDescription());
            workList.add(row);
        }

        List<Map<String, Object>> projectList = new ArrayList<>();
        for (EntResumeSnapshot.Project item : snapshot.getProjects())
        {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("name", item.getName());
            row.put("role", item.getRole());
            row.put("techStack", item.getTechStack());
            row.put("summary", item.getDescription());
            projectList.add(row);
        }

        List<Map<String, Object>> skillList = new ArrayList<>();
        for (EntResumeSnapshot.Skill item : snapshot.getSkills())
        {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("name", item.getName());
            row.put("level", item.getLevel());
            skillList.add(row);
        }

        // 快照不含手机/邮箱字段，完整度仅基于可判定的教育/工作/技能三项
        List<String> missingFields = new ArrayList<>();
        if (educationList.isEmpty()) missingFields.add("教育经历");
        if (workList.isEmpty()) missingFields.add("工作经历");
        if (skillList.isEmpty()) missingFields.add("技能标签");
        int filled = 3 - missingFields.size();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("applicationId", snapshot.getAppId());
        result.put("snapshotId", snapshot.getId());
        result.put("jobDirection", snapshot.getJobDirection());
        result.put("educationList", educationList);
        result.put("workList", workList);
        result.put("projectList", projectList);
        result.put("skills", skillList);
        result.put("missingFields", missingFields);
        result.put("integrity", filled * 100 / 3);
        result.put("fileName", snapshot.getFileName());
        // 标记为投递快照口径，前端据此与人才库当前简历区分
        result.put("resumeScope", "application_snapshot");
        result.put("resumeScopeLabel", "岗位投递简历快照");
        return result;
    }

    /** LocalDate 格式化为 yyyy-MM；为空返回 null，前端按未填写处理。 */
    private String formatMonth(LocalDate date)
    {
        return date == null ? null : date.format(MONTH_FORMATTER);
    }
}
