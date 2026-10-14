package com.ruoyi.system.domain.agent;

import java.math.BigDecimal;
import java.util.Date;
import java.util.List;
import java.util.Map;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * 求职者端岗位视图对象。
 */
public class AgentJob
{
    private Long id;
    private String title;
    private String category;
    private Long companyId;
    private String companyName;
    private String companyLogoUrl;
    private String companyIndustry;
    private String companySize;
    private String companyCity;
    private String companyAddress;
    private String companyIntro;
    private Map<String, Object> companyDetails;
    private String workCity;
    private BigDecimal salaryMin;
    private BigDecimal salaryMax;
    private String salaryText;
    private String experienceRequired;
    private Integer educationRequired;
    private String educationText;
    private Integer jobType;
    private String jobTypeText;
    private String jdJson;
    private List<String> responsibilities;
    private List<String> requirements;
    private List<String> skills;
    private Integer statusCode;
    private String status;
    private String statusText;
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ssXXX", timezone = "Asia/Shanghai")
    private Date publishedAt;
    private Integer appliedFlag;
    private Long applicationId;
    private BigDecimal matchScore;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }
    public Long getCompanyId() { return companyId; }
    public void setCompanyId(Long companyId) { this.companyId = companyId; }
    public String getCompanyName() { return companyName; }
    public void setCompanyName(String companyName) { this.companyName = companyName; }
    public String getCompanyLogoUrl() { return companyLogoUrl; }
    public void setCompanyLogoUrl(String companyLogoUrl) { this.companyLogoUrl = companyLogoUrl; }
    public String getCompanyIndustry() { return companyIndustry; }
    public void setCompanyIndustry(String companyIndustry) { this.companyIndustry = companyIndustry; }
    public String getCompanySize() { return companySize; }
    public void setCompanySize(String companySize) { this.companySize = companySize; }
    public String getCompanyCity() { return companyCity; }
    public void setCompanyCity(String companyCity) { this.companyCity = companyCity; }
    public String getCompanyAddress() { return companyAddress; }
    public void setCompanyAddress(String companyAddress) { this.companyAddress = companyAddress; }
    public String getCompanyIntro() { return companyIntro; }
    public void setCompanyIntro(String companyIntro) { this.companyIntro = companyIntro; }
    public Map<String, Object> getCompanyDetails() { return companyDetails; }
    public void setCompanyDetails(Map<String, Object> companyDetails) { this.companyDetails = companyDetails; }
    public String getWorkCity() { return workCity; }
    public void setWorkCity(String workCity) { this.workCity = workCity; }
    public BigDecimal getSalaryMin() { return salaryMin; }
    public void setSalaryMin(BigDecimal salaryMin) { this.salaryMin = salaryMin; }
    public BigDecimal getSalaryMax() { return salaryMax; }
    public void setSalaryMax(BigDecimal salaryMax) { this.salaryMax = salaryMax; }
    public String getSalaryText() { return salaryText; }
    public void setSalaryText(String salaryText) { this.salaryText = salaryText; }
    public String getExperienceRequired() { return experienceRequired; }
    public void setExperienceRequired(String experienceRequired) { this.experienceRequired = experienceRequired; }
    public Integer getEducationRequired() { return educationRequired; }
    public void setEducationRequired(Integer educationRequired) { this.educationRequired = educationRequired; }
    public String getEducationText() { return educationText; }
    public void setEducationText(String educationText) { this.educationText = educationText; }
    public Integer getJobType() { return jobType; }
    public void setJobType(Integer jobType) { this.jobType = jobType; }
    public String getJobTypeText() { return jobTypeText; }
    public void setJobTypeText(String jobTypeText) { this.jobTypeText = jobTypeText; }
    public String getJdJson() { return jdJson; }
    public void setJdJson(String jdJson) { this.jdJson = jdJson; }
    public List<String> getResponsibilities() { return responsibilities; }
    public void setResponsibilities(List<String> responsibilities) { this.responsibilities = responsibilities; }
    public List<String> getRequirements() { return requirements; }
    public void setRequirements(List<String> requirements) { this.requirements = requirements; }
    public List<String> getSkills() { return skills; }
    public void setSkills(List<String> skills) { this.skills = skills; }
    public Integer getStatusCode() { return statusCode; }
    public void setStatusCode(Integer statusCode) { this.statusCode = statusCode; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getStatusText() { return statusText; }
    public void setStatusText(String statusText) { this.statusText = statusText; }
    public Date getPublishedAt() { return publishedAt; }
    public void setPublishedAt(Date publishedAt) { this.publishedAt = publishedAt; }
    public Integer getAppliedFlag() { return appliedFlag; }
    public void setAppliedFlag(Integer appliedFlag) { this.appliedFlag = appliedFlag; }
    public Long getApplicationId() { return applicationId; }
    public void setApplicationId(Long applicationId) { this.applicationId = applicationId; }
    public BigDecimal getMatchScore() { return matchScore; }
    public void setMatchScore(BigDecimal matchScore) { this.matchScore = matchScore; }
}
