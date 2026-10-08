package com.ruoyi.system.domain.app;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

/** C-App 岗位卡片。 */
public class AppJob implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long positionId;
    private String title;
    private Long companyId;
    private String company;
    private String companyLogo;
    private Integer companyVerified;
    private String city;
    private BigDecimal salaryMin;
    private BigDecimal salaryMax;
    private String experience;
    private Integer education;
    private Integer jobType;
    private Integer matchScore;
    private String description;
    private String tagsCsv;
    private Boolean applied;

    public Long getPositionId() { return positionId; }
    public void setPositionId(Long positionId) { this.positionId = positionId; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public Long getCompanyId() { return companyId; }
    public void setCompanyId(Long companyId) { this.companyId = companyId; }
    public String getCompany() { return company; }
    public void setCompany(String company) { this.company = company; }
    public String getCompanyLogo() { return companyLogo; }
    public void setCompanyLogo(String companyLogo) { this.companyLogo = companyLogo; }
    public Integer getCompanyVerified() { return companyVerified; }
    public void setCompanyVerified(Integer companyVerified) { this.companyVerified = companyVerified; }
    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
    public BigDecimal getSalaryMin() { return salaryMin; }
    public void setSalaryMin(BigDecimal salaryMin) { this.salaryMin = salaryMin; }
    public BigDecimal getSalaryMax() { return salaryMax; }
    public void setSalaryMax(BigDecimal salaryMax) { this.salaryMax = salaryMax; }
    public String getExperience() { return experience; }
    public void setExperience(String experience) { this.experience = experience; }
    public Integer getEducation() { return education; }
    public void setEducation(Integer education) { this.education = education; }
    public Integer getJobType() { return jobType; }
    public void setJobType(Integer jobType) { this.jobType = jobType; }
    public Integer getMatchScore() { return matchScore; }
    public void setMatchScore(Integer matchScore) { this.matchScore = matchScore; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public void setTagsCsv(String tagsCsv) { this.tagsCsv = tagsCsv; }
    public Boolean getApplied() { return applied; }
    public void setApplied(Boolean applied) { this.applied = applied; }

    public List<String> getTags()
    {
        if (tagsCsv == null || tagsCsv.isBlank())
        {
            return new ArrayList<>();
        }
        return Arrays.stream(tagsCsv.split(","))
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .limit(4)
                .collect(Collectors.toList());
    }
}
