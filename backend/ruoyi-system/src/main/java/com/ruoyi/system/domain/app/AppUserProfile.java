package com.ruoyi.system.domain.app;

import java.io.Serializable;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * C 端用户个人中心资料。
 */
public class AppUserProfile implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long userId;
    private String userName;

    @NotBlank(message = "用户昵称不能为空")
    @Size(max = 30, message = "用户昵称长度不能超过30个字符")
    private String nickName;

    @Size(max = 50, message = "真实姓名长度不能超过50个字符")
    private String realName;

    private String avatar;

    @Email(message = "邮箱格式不正确")
    @Size(max = 100, message = "邮箱长度不能超过100个字符")
    private String email;

    @Size(max = 20, message = "手机号码长度不能超过20个字符")
    private String phonenumber;

    private String sex;

    @Size(max = 500, message = "个人简介长度不能超过500个字符")
    private String remark;

    @Size(max = 50, message = "所在城市长度不能超过50个字符")
    private String currentCity;

    @Min(value = 1, message = "职业状态不正确")
    @Max(value = 3, message = "职业状态不正确")
    private Integer currentStatus;

    @Size(max = 100, message = "期望职位长度不能超过100个字符")
    private String targetDirection;

    @Size(max = 50, message = "期望城市长度不能超过50个字符")
    private String targetCity;

    private Integer salaryMin;
    private Integer salaryMax;
    private Integer salaryNegotiable;
    private boolean salaryProvided;

    public Integer getSalaryMin() { return salaryMin; }
    public void setSalaryMin(Integer value) { salaryMin = value; salaryProvided = true; }
    public Integer getSalaryMax() { return salaryMax; }
    public void setSalaryMax(Integer value) { salaryMax = value; salaryProvided = true; }
    public Integer getSalaryNegotiable() { return salaryNegotiable; }
    public void setSalaryNegotiable(Integer value) { salaryNegotiable = value; salaryProvided = true; }
    @com.fasterxml.jackson.annotation.JsonIgnore
    public boolean isSalaryProvided() { return salaryProvided; }

    public void validateSalary()
    {
        if (!salaryProvided) return;
        if (salaryNegotiable == null || salaryNegotiable == 1)
        {
            if (salaryMin == null && salaryMax == null) return;
        }
        else if (salaryNegotiable == 0 && salaryMin != null && salaryMax != null
                && salaryMin >= 0 && salaryMin <= salaryMax && salaryMax <= 10000000) return;
        throw new com.ruoyi.common.exception.ServiceException("期望薪资须选择未填写、面议或合法人民币月薪区间");
    }

    private Integer verifyStatus;
    private Integer applicationCount;
    private Integer interviewCount;
    private Integer favoriteCount;
    private Integer workYears;
    private String updateBy;

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getUserName() { return userName; }
    public void setUserName(String userName) { this.userName = userName; }
    public String getNickName() { return nickName; }
    public void setNickName(String nickName) { this.nickName = nickName; }
    public String getRealName() { return realName; }
    public void setRealName(String realName) { this.realName = realName; }
    public String getAvatar() { return avatar; }
    public void setAvatar(String avatar) { this.avatar = avatar; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPhonenumber() { return phonenumber; }
    public void setPhonenumber(String phonenumber) { this.phonenumber = phonenumber; }
    public String getSex() { return sex; }
    public void setSex(String sex) { this.sex = sex; }
    public String getRemark() { return remark; }
    public void setRemark(String remark) { this.remark = remark; }
    public String getCurrentCity() { return currentCity; }
    public void setCurrentCity(String currentCity) { this.currentCity = currentCity; }
    public Integer getCurrentStatus() { return currentStatus; }
    public void setCurrentStatus(Integer currentStatus) { this.currentStatus = currentStatus; }
    public String getTargetDirection() { return targetDirection; }
    public void setTargetDirection(String targetDirection) { this.targetDirection = targetDirection; }
    public String getTargetCity() { return targetCity; }
    public void setTargetCity(String targetCity) { this.targetCity = targetCity; }
    public Integer getVerifyStatus() { return verifyStatus; }
    public void setVerifyStatus(Integer verifyStatus) { this.verifyStatus = verifyStatus; }
    public Integer getApplicationCount() { return applicationCount; }
    public void setApplicationCount(Integer applicationCount) { this.applicationCount = applicationCount; }
    public Integer getInterviewCount() { return interviewCount; }
    public void setInterviewCount(Integer interviewCount) { this.interviewCount = interviewCount; }
    public Integer getFavoriteCount() { return favoriteCount; }
    public void setFavoriteCount(Integer favoriteCount) { this.favoriteCount = favoriteCount; }
    public Integer getWorkYears() { return workYears; }
    public void setWorkYears(Integer workYears) { this.workYears = workYears; }
    public String getUpdateBy() { return updateBy; }
    public void setUpdateBy(String updateBy) { this.updateBy = updateBy; }
}
