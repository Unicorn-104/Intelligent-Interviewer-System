package com.ruoyi.system.domain.agent;

import java.util.ArrayList;
import java.util.List;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 求职者端简历保存请求。
 */
public class AgentResumeUpdateRequest
{
    @NotBlank(message = "简历名称不能为空")
    @Size(max = 100, message = "简历名称不能超过100个字符")
    private String resumeName;

    @Size(max = 50, message = "求职方向不能超过50个字符")
    private String jobDirection;

    @Size(max = 50, message = "姓名不能超过50个字符")
    private String realName;

    @Size(max = 10, message = "性别不能超过10个字符")
    private String gender;

    @Size(max = 30, message = "工作状态不能超过30个字符")
    private String workStatus;

    @Size(max = 50, message = "所在城市不能超过50个字符")
    private String currentCity;

    @Size(max = 20, message = "手机号不能超过20个字符")
    private String phone;

    @Size(max = 100, message = "邮箱不能超过100个字符")
    private String email;

    @Size(max = 50, message = "期望职位不能超过50个字符")
    private String targetRole;

    @Size(max = 50, message = "期望薪资不能超过50个字符")
    private String salaryExpectation;

    @Size(max = 100, message = "期望城市不能超过100个字符")
    private String targetCity;

    @Size(max = 30, message = "到岗时间不能超过30个字符")
    private String arrivalTime;

    @Valid
    private List<AgentResumeEducation> educations = new ArrayList<>();

    @Valid
    private List<AgentResumeWork> works = new ArrayList<>();

    @Valid
    private List<AgentResumeProject> projects = new ArrayList<>();

    @Valid
    private List<AgentResumeSkill> skills = new ArrayList<>();

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
    public List<AgentResumeEducation> getEducations() { return educations; }
    public void setEducations(List<AgentResumeEducation> educations) { this.educations = educations; }
    public List<AgentResumeWork> getWorks() { return works; }
    public void setWorks(List<AgentResumeWork> works) { this.works = works; }
    public List<AgentResumeProject> getProjects() { return projects; }
    public void setProjects(List<AgentResumeProject> projects) { this.projects = projects; }
    public List<AgentResumeSkill> getSkills() { return skills; }
    public void setSkills(List<AgentResumeSkill> skills) { this.skills = skills; }
}
