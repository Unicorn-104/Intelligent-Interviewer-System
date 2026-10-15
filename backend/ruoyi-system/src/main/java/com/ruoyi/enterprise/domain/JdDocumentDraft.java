package com.ruoyi.enterprise.domain;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/** Editable draft only; contains no database IDs, storage paths or publishing state. */
public class JdDocumentDraft
{
    private String title;
    private String dept;
    private String city;
    private BigDecimal salaryMin;
    private BigDecimal salaryMax;
    private String experience;
    private Integer education;
    private Integer jobType;
    private List<String> responsibilities = new ArrayList<>();
    private List<String> requirements = new ArrayList<>();
    private String summary;
    private List<String> softRequirements = new ArrayList<>();
    private List<Skill> skills = new ArrayList<>();
    private List<String> warnings = new ArrayList<>();

    public record Skill(String name, Integer required) { }

    public String getTitle() { return title; }
    public void setTitle(String value) { title = value; }
    public String getDept() { return dept; }
    public void setDept(String value) { dept = value; }
    public String getCity() { return city; }
    public void setCity(String value) { city = value; }
    public BigDecimal getSalaryMin() { return salaryMin; }
    public void setSalaryMin(BigDecimal value) { salaryMin = value; }
    public BigDecimal getSalaryMax() { return salaryMax; }
    public void setSalaryMax(BigDecimal value) { salaryMax = value; }
    public String getExperience() { return experience; }
    public void setExperience(String value) { experience = value; }
    public Integer getEducation() { return education; }
    public void setEducation(Integer value) { education = value; }
    public Integer getJobType() { return jobType; }
    public void setJobType(Integer value) { jobType = value; }
    public List<String> getResponsibilities() { return responsibilities; }
    public void setResponsibilities(List<String> value) { responsibilities = new ArrayList<>(value); }
    public List<String> getRequirements() { return requirements; }
    public void setRequirements(List<String> value) { requirements = new ArrayList<>(value); }
    public String getSummary() { return summary; }
    public void setSummary(String value) { summary = value; }
    public List<String> getSoftRequirements() { return softRequirements; }
    public void setSoftRequirements(List<String> value) { softRequirements = new ArrayList<>(value); }
    public List<Skill> getSkills() { return skills; }
    public void setSkills(List<Skill> value) { skills = new ArrayList<>(value); }
    public List<String> getWarnings() { return warnings; }
    public void setWarnings(List<String> value) { warnings = new ArrayList<>(value); }
}
