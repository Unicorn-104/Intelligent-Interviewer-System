package com.ruoyi.system.domain.agent;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonIgnore;

/**
 * 求职者端简历详情。
 */
public class AgentResumeDetail
{
    private Long id;
    @JsonIgnore
    private Long userId;
    private String resumeName;
    private String jobDirection;
    private String realName;
    private String gender;
    private String workStatus;
    private String currentCity;
    private String phone;
    private String email;
    private String targetRole;
    private String salaryExpectation;
    private String targetCity;
    private String arrivalTime;
    private Boolean isDefault;
    private Integer completion;
    private Integer usedApplicationCount;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private Date updatedAt;

    private String fileName;
    private Long fileSize;
    private String fileUrl;

    private String parseMethod;
    private String structureMethod;
    private String unmappedText;
    private List<String> parseWarnings = new ArrayList<>();

    @JsonIgnore
    private String filePath;

    private List<AgentResumeEducation> educations = new ArrayList<>();
    private List<AgentResumeWork> works = new ArrayList<>();
    private List<AgentResumeProject> projects = new ArrayList<>();
    private List<AgentResumeSkill> skills = new ArrayList<>();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getResumeName() { return resumeName; }
    public void setResumeName(String resumeName) { this.resumeName = resumeName; }
    public String getJobDirection() { return jobDirection; }
    public void setJobDirection(String jobDirection) { this.jobDirection = jobDirection; }
    public String getRealName() { return realName; }
    public void setRealName(String realName) { this.realName = realName; }
    public String getGender() { return gender; }
    public void setGender(String gender) { this.gender = gender; }
    public String getWorkStatus() { return workStatus; }
    public void setWorkStatus(String workStatus) { this.workStatus = workStatus; }
    public String getCurrentCity() { return currentCity; }
    public void setCurrentCity(String currentCity) { this.currentCity = currentCity; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getTargetRole() { return targetRole; }
    public void setTargetRole(String targetRole) { this.targetRole = targetRole; }
    public String getSalaryExpectation() { return salaryExpectation; }
    public void setSalaryExpectation(String salaryExpectation) { this.salaryExpectation = salaryExpectation; }
    public String getTargetCity() { return targetCity; }
    public void setTargetCity(String targetCity) { this.targetCity = targetCity; }
    public String getArrivalTime() { return arrivalTime; }
    public void setArrivalTime(String arrivalTime) { this.arrivalTime = arrivalTime; }
    public Boolean getIsDefault() { return isDefault; }
    public void setIsDefault(Boolean isDefault) { this.isDefault = isDefault; }
    public Integer getCompletion() { return completion; }
    public void setCompletion(Integer completion) { this.completion = completion; }
    public Integer getUsedApplicationCount() { return usedApplicationCount; }
    public void setUsedApplicationCount(Integer usedApplicationCount) { this.usedApplicationCount = usedApplicationCount; }
    public Date getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Date updatedAt) { this.updatedAt = updatedAt; }
    public String getFileName() { return fileName; }
    public void setFileName(String fileName) { this.fileName = fileName; }
    public Long getFileSize() { return fileSize; }
    public void setFileSize(Long fileSize) { this.fileSize = fileSize; }
    public String getFileUrl() { return fileUrl; }
    public void setFileUrl(String fileUrl) { this.fileUrl = fileUrl; }
    public String getParseMethod() { return parseMethod; }
    public void setParseMethod(String parseMethod) { this.parseMethod = parseMethod; }
    public String getStructureMethod() { return structureMethod; }
    public void setStructureMethod(String structureMethod) { this.structureMethod = structureMethod; }
    public String getUnmappedText() { return unmappedText; }
    public void setUnmappedText(String unmappedText) { this.unmappedText = unmappedText; }
    public List<String> getParseWarnings() { return parseWarnings; }
    public void setParseWarnings(List<String> parseWarnings)
    {
        this.parseWarnings = parseWarnings == null ? new ArrayList<>() : parseWarnings;
    }
    public String getFilePath() { return filePath; }
    public void setFilePath(String filePath) { this.filePath = filePath; }
    public List<AgentResumeEducation> getEducations() { return educations; }
    public void setEducations(List<AgentResumeEducation> educations) { this.educations = educations; }
    public List<AgentResumeWork> getWorks() { return works; }
    public void setWorks(List<AgentResumeWork> works) { this.works = works; }
    public List<AgentResumeProject> getProjects() { return projects; }
    public void setProjects(List<AgentResumeProject> projects) { this.projects = projects; }
    public List<AgentResumeSkill> getSkills() { return skills; }
    public void setSkills(List<AgentResumeSkill> skills) { this.skills = skills; }
}
