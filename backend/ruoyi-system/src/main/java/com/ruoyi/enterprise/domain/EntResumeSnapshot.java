package com.ruoyi.enterprise.domain;

import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 企业投递简历快照。
 *
 * <p>每次岗位投递生成一条不可变快照，物理表与 C-App 的 t_res_base 分离；
 * 企业查看投递简历、PDF 下载、AI 分析均以本快照为唯一读取来源。</p>
 */
public class EntResumeSnapshot implements Serializable
{
    private static final long serialVersionUID = 1L;

    /** 快照状态：完整可用 */
    public static final String STATUS_COMPLETE = "COMPLETE";
    /** 现存数据重建、原始版本未核实 */
    public static final String STATUS_REBUILT_UNVERIFIED = "REBUILT_UNVERIFIED";
    /** 来源缺失、待人工核实 */
    public static final String STATUS_MISSING_SOURCE = "MISSING_SOURCE";

    /** 原始版本核实证据：实时投递天然原件 */
    public static final String VERSION_LIVE_ORIGINAL = "LIVE_ORIGINAL";
    /** 原始版本核实证据：历史快照经人工可靠证据核实 */
    public static final String VERSION_MANUAL_VERIFIED = "MANUAL_VERIFIED";

    /** 时间来源：实时投递真实时间 */
    public static final String TIME_LIVE_REAL = "LIVE_REAL";
    /** 时间来源：历史回填、存在真实投递时间 */
    public static final String TIME_BACKFILL_REAL = "BACKFILL_REAL";
    /** 时间来源：历史回填、投递时间未知（snapshot_at 保持 NULL，不伪造） */
    public static final String TIME_BACKFILL_UNKNOWN = "BACKFILL_UNKNOWN";

    /** AI 来源：历史报告无法识别来源，不默认归类 llm */
    public static final String SOURCE_UNKNOWN = "unknown";

    private Long id;
    private Long appId;
    private Long candidateId;
    private Long companyId;
    private Long positionId;
    private Long sourceResumeId;
    private String resumeName;
    private String jobDirection;
    private String filePath;
    private String fileName;
    private Long fileSize;
    private String contentHash;
    private String snapshotStatus;
    private String versionVerified;
    private String timeSource;
    private LocalDateTime snapshotAt;
    private LocalDateTime createdAt;

    private List<Education> educations = new ArrayList<>();
    private List<Work> works = new ArrayList<>();
    private List<Project> projects = new ArrayList<>();
    private List<Skill> skills = new ArrayList<>();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getAppId() { return appId; }
    public void setAppId(Long appId) { this.appId = appId; }
    public Long getCandidateId() { return candidateId; }
    public void setCandidateId(Long candidateId) { this.candidateId = candidateId; }
    public Long getCompanyId() { return companyId; }
    public void setCompanyId(Long companyId) { this.companyId = companyId; }
    public Long getPositionId() { return positionId; }
    public void setPositionId(Long positionId) { this.positionId = positionId; }
    public Long getSourceResumeId() { return sourceResumeId; }
    public void setSourceResumeId(Long sourceResumeId) { this.sourceResumeId = sourceResumeId; }
    public String getResumeName() { return resumeName; }
    public void setResumeName(String resumeName) { this.resumeName = resumeName; }
    public String getJobDirection() { return jobDirection; }
    public void setJobDirection(String jobDirection) { this.jobDirection = jobDirection; }
    public String getFilePath() { return filePath; }
    public void setFilePath(String filePath) { this.filePath = filePath; }
    public String getFileName() { return fileName; }
    public void setFileName(String fileName) { this.fileName = fileName; }
    public Long getFileSize() { return fileSize; }
    public void setFileSize(Long fileSize) { this.fileSize = fileSize; }
    public String getContentHash() { return contentHash; }
    public void setContentHash(String contentHash) { this.contentHash = contentHash; }
    public String getSnapshotStatus() { return snapshotStatus; }
    public void setSnapshotStatus(String snapshotStatus) { this.snapshotStatus = snapshotStatus; }
    public String getVersionVerified() { return versionVerified; }
    public void setVersionVerified(String versionVerified) { this.versionVerified = versionVerified; }
    public String getTimeSource() { return timeSource; }
    public void setTimeSource(String timeSource) { this.timeSource = timeSource; }
    public LocalDateTime getSnapshotAt() { return snapshotAt; }
    public void setSnapshotAt(LocalDateTime snapshotAt) { this.snapshotAt = snapshotAt; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public List<Education> getEducations() { return educations; }
    public void setEducations(List<Education> educations)
    {
        this.educations = educations == null ? new ArrayList<>() : educations;
    }
    public List<Work> getWorks() { return works; }
    public void setWorks(List<Work> works)
    {
        this.works = works == null ? new ArrayList<>() : works;
    }
    public List<Project> getProjects() { return projects; }
    public void setProjects(List<Project> projects)
    {
        this.projects = projects == null ? new ArrayList<>() : projects;
    }
    public List<Skill> getSkills() { return skills; }
    public void setSkills(List<Skill> skills)
    {
        this.skills = skills == null ? new ArrayList<>() : skills;
    }

    /** 教育经历，字段语义对齐 C-App t_res_education。 */
    public static class Education implements Serializable
    {
        private static final long serialVersionUID = 1L;
        private Long educationId;
        private String school;
        private String major;
        private Integer degree;
        private LocalDate startDate;
        private LocalDate endDate;
        private BigDecimal gpa;
        private String description;
        public Long getEducationId() { return educationId; }
        public void setEducationId(Long educationId) { this.educationId = educationId; }
        public String getSchool() { return school; }
        public void setSchool(String school) { this.school = school; }
        public String getMajor() { return major; }
        public void setMajor(String major) { this.major = major; }
        public Integer getDegree() { return degree; }
        public void setDegree(Integer degree) { this.degree = degree; }
        public LocalDate getStartDate() { return startDate; }
        public void setStartDate(LocalDate startDate) { this.startDate = startDate; }
        public LocalDate getEndDate() { return endDate; }
        public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
        public BigDecimal getGpa() { return gpa; }
        public void setGpa(BigDecimal gpa) { this.gpa = gpa; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
    }

    /** 工作经历，对齐 t_res_work。 */
    public static class Work implements Serializable
    {
        private static final long serialVersionUID = 1L;
        private Long workId;
        private String company;
        private String position;
        private String department;
        private LocalDate startDate;
        private LocalDate endDate;
        private Boolean current;
        private String salaryRange;
        private String description;
        public Long getWorkId() { return workId; }
        public void setWorkId(Long workId) { this.workId = workId; }
        public String getCompany() { return company; }
        public void setCompany(String company) { this.company = company; }
        public String getPosition() { return position; }
        public void setPosition(String position) { this.position = position; }
        public String getDepartment() { return department; }
        public void setDepartment(String department) { this.department = department; }
        public LocalDate getStartDate() { return startDate; }
        public void setStartDate(LocalDate startDate) { this.startDate = startDate; }
        public LocalDate getEndDate() { return endDate; }
        public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
        public Boolean getCurrent() { return current; }
        public void setCurrent(Boolean current) { this.current = current; }
        public String getSalaryRange() { return salaryRange; }
        public void setSalaryRange(String salaryRange) { this.salaryRange = salaryRange; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
    }

    /** 项目经历，对齐 t_res_project。 */
    public static class Project implements Serializable
    {
        private static final long serialVersionUID = 1L;
        private Long projectId;
        private String name;
        private String role;
        private LocalDate startDate;
        private LocalDate endDate;
        private String description;
        private String techStack;
        public Long getProjectId() { return projectId; }
        public void setProjectId(Long projectId) { this.projectId = projectId; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getRole() { return role; }
        public void setRole(String role) { this.role = role; }
        public LocalDate getStartDate() { return startDate; }
        public void setStartDate(LocalDate startDate) { this.startDate = startDate; }
        public LocalDate getEndDate() { return endDate; }
        public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
        public String getTechStack() { return techStack; }
        public void setTechStack(String techStack) { this.techStack = techStack; }
    }

    /** 技能，对齐 t_res_skill。 */
    public static class Skill implements Serializable
    {
        private static final long serialVersionUID = 1L;
        private Long skillId;
        private String name;
        private Integer level;
        public Long getSkillId() { return skillId; }
        public void setSkillId(Long skillId) { this.skillId = skillId; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public Integer getLevel() { return level; }
        public void setLevel(Integer level) { this.level = level; }
    }
}
