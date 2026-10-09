package com.ruoyi.system.domain.agent;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/**
 * 求职者端岗位查询参数。
 */
public class AgentJobQuery
{
    private String keyword;
    private String city;
    private String district;
    private String employmentType;
    private String experienceMin;
    private Integer education;
    private String sort = "latest";

    @Min(1)
    private Integer page = 1;

    @Min(1)
    @Max(100)
    private Integer size = 10;

    public String getKeyword() { return keyword; }
    public void setKeyword(String keyword) { this.keyword = keyword; }
    public String getCity() { return city; }
    public void setCity(String city) { this.city = city; }
    public String getDistrict() { return district; }
    public void setDistrict(String district) { this.district = district; }
    public String getEmploymentType() { return employmentType; }
    public void setEmploymentType(String employmentType) { this.employmentType = employmentType; }
    public String getExperienceMin() { return experienceMin; }
    public void setExperienceMin(String experienceMin) { this.experienceMin = experienceMin; }
    public Integer getEducation() { return education; }
    public void setEducation(Integer education) { this.education = education; }
    public String getSort() { return sort; }
    public void setSort(String sort) { this.sort = sort; }
    public Integer getPage() { return page; }
    public void setPage(Integer page) { this.page = page; }
    public Integer getSize() { return size; }
    public void setSize(Integer size) { this.size = size; }
}
