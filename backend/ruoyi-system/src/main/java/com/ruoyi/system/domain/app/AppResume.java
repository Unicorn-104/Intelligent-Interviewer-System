package com.ruoyi.system.domain.app;

import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;

/** C-App 结构化简历。 */
public class AppResume implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long resumeId;
    private Long userId;
    @NotBlank(message = "简历名称不能为空")
    @Size(max = 100, message = "简历名称不能超过100个字符")
    private String resumeName;
    @Size(max = 50, message = "求职方向不能超过50个字符")
    private String jobDirection;
    private Boolean isDefault;
    private Integer status;
    private LocalDateTime updatedAt;
    private Integer completeness;
    private Integer educationCount;
    private Integer workCount;
    private Integer projectCount;
    private Integer skillCount;
    @JsonIgnore
    private String filePath;
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    private String fileName;
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    private Long fileSize;
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    private String extractedText;
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    private String parseMethod;
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    private String structureMethod;
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    private String unmappedText;
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    private List<String> parseWarnings = new ArrayList<>();
    @Valid
    private List<Education> educations = new ArrayList<>();
    @Valid
    private List<Work> works = new ArrayList<>();
    @Valid
    private List<Project> projects = new ArrayList<>();
    @Valid
    private List<Skill> skills = new ArrayList<>();

    public Long getResumeId() { return resumeId; }
    public void setResumeId(Long resumeId) { this.resumeId = resumeId; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getResumeName() { return resumeName; }
    public void setResumeName(String resumeName) { this.resumeName = resumeName; }
    public String getJobDirection() { return jobDirection; }
    public void setJobDirection(String jobDirection) { this.jobDirection = jobDirection; }
    public Boolean getIsDefault() { return isDefault; }
    public void setIsDefault(Boolean isDefault) { this.isDefault = isDefault; }
    public Integer getStatus() { return status; }
    public void setStatus(Integer status) { this.status = status; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
    public Integer getCompleteness() { return completeness; }
    public void setCompleteness(Integer completeness) { this.completeness = completeness; }
    public Integer getEducationCount() { return educationCount; }
    public void setEducationCount(Integer educationCount) { this.educationCount = educationCount; }
    public Integer getWorkCount() { return workCount; }
    public void setWorkCount(Integer workCount) { this.workCount = workCount; }
    public Integer getProjectCount() { return projectCount; }
    public void setProjectCount(Integer projectCount) { this.projectCount = projectCount; }
    public Integer getSkillCount() { return skillCount; }
    public void setSkillCount(Integer skillCount) { this.skillCount = skillCount; }
    @JsonIgnore
    public String getFilePath() { return filePath; }
    public void setFilePath(String value) { filePath = value; }
    public String getFileName() { return fileName; }
    public void setFileName(String value) { fileName = value; }
    public Long getFileSize() { return fileSize; }
    public void setFileSize(Long value) { fileSize = value; }
    public String getExtractedText() { return extractedText; }
    public void setExtractedText(String value) { extractedText = value; }
    public String getParseMethod() { return parseMethod; }
    public void setParseMethod(String value) { parseMethod = value; }
    public String getStructureMethod() { return structureMethod; }
    public void setStructureMethod(String value) { structureMethod = value; }
    public String getUnmappedText() { return unmappedText; }
    public void setUnmappedText(String value) { unmappedText = value; }
    public List<String> getParseWarnings() { return parseWarnings; }
    public void setParseWarnings(List<String> value) { parseWarnings = value == null ? new ArrayList<>() : value; }
    @JsonProperty(access = JsonProperty.Access.READ_ONLY)
    public String getPdfUrl()
    {
        return resumeId != null && filePath != null && !filePath.isBlank()
                ? "/app/resumes/" + resumeId + "/pdf" : null;
    }
    public List<Education> getEducations() { return educations; }
    public void setEducations(List<Education> educations) { this.educations = educations == null ? new ArrayList<>() : educations; }
    public List<Work> getWorks() { return works; }
    public void setWorks(List<Work> works) { this.works = works == null ? new ArrayList<>() : works; }
    public List<Project> getProjects() { return projects; }
    public void setProjects(List<Project> projects) { this.projects = projects == null ? new ArrayList<>() : projects; }
    public List<Skill> getSkills() { return skills; }
    public void setSkills(List<Skill> skills) { this.skills = skills == null ? new ArrayList<>() : skills; }

    public static class Education implements Serializable
    {
        private Long educationId;
        @NotBlank(message = "学校名称不能为空") private String school;
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

    public static class Work implements Serializable
    {
        private Long workId;
        @NotBlank(message = "公司名称不能为空") private String company;
        @NotBlank(message = "职位不能为空") private String position;
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

    public static class Project implements Serializable
    {
        private Long projectId;
        @NotBlank(message = "项目名称不能为空") private String name;
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

    public static class Skill implements Serializable
    {
        private Long skillId;
        @NotBlank(message = "技能名称不能为空") private String name;
        private Integer level = 2;
        public Long getSkillId() { return skillId; }
        public void setSkillId(Long skillId) { this.skillId = skillId; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public Integer getLevel() { return level; }
        public void setLevel(Integer level) { this.level = level; }
    }
}
