package com.ruoyi.system.domain.agent;

import java.math.BigDecimal;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/**
 * 求职者端岗位查询参数。
 */
public class AgentJobQuery
{
    @Min(1)
    private Long companyId;
    private String keyword;
    private String category;
    private String city;
    private String district;
    private String employmentType;
    private BigDecimal salaryMin;
    private BigDecimal salaryMax;
    private String experienceMin;
    private Integer education;
    private String industry;
    private String companySize;
    private String sort = "latest";

    @Min(1)
    private Integer page = 1;

    @Min(1)
    @Max(100)
    private Integer size = 10;

    public Long getCompanyId() { return companyId; }
    public void setCompanyId(Long companyId) { this.companyId = companyId; }
    public String getKeyword() { return keyword; }
    public void setKeyword(String keyword) { this.keyword = keyword; }
    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }
    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
    public String getDistrict() { return district; }
    public void setDistrict(String district) { this.district = district; }
    public String getEmploymentType() { return employmentType; }
    public void setEmploymentType(String employmentType) { this.employmentType = employmentType; }
    public BigDecimal getSalaryMin() { return salaryMin; }
    public void setSalaryMin(BigDecimal salaryMin) { this.salaryMin = salaryMin; }
    public BigDecimal getSalaryMax() { return salaryMax; }
    public void setSalaryMax(BigDecimal salaryMax) { this.salaryMax = salaryMax; }
    public String getExperienceMin() { return experienceMin; }
    public void setExperienceMin(String experienceMin) { this.experienceMin = experienceMin; }
    public Integer getEducation() { return education; }
    public void setEducation(Integer education) { this.education = education; }
    public String getIndustry() { return industry; }
    public void setIndustry(String industry) { this.industry = industry; }
    public String getCompanySize() { return companySize; }
    public void setCompanySize(String companySize) { this.companySize = companySize; }
    public String getSort() { return sort; }
    public void setSort(String sort) { this.sort = sort; }
    public Integer getPage() { return page; }
    public void setPage(Integer page) { this.page = page; }
    public Integer getSize() { return size; }
    public void setSize(Integer size) { this.size = size; }
}
