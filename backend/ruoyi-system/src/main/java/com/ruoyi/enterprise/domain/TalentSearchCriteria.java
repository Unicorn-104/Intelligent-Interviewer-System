package com.ruoyi.enterprise.domain;

import java.time.LocalDateTime;
import java.util.List;
import com.ruoyi.common.exception.ServiceException;

/** Optional, backwards-compatible talent-search criteria. No schema changes. */
public class TalentSearchCriteria
{
    private Integer minimumEducation;
    private String experienceRange;
    private String city;
    private String cityType = "target";
    private Integer loginWithinDays;
    private LocalDateTime referenceTime;

    public void validate()
    {
        if (minimumEducation != null && (minimumEducation < 1 || minimumEducation > 5))
            throw new ServiceException("学历筛选值不合法");
        experienceRange = trim(experienceRange);
        if (experienceRange != null && !List.of("lt1", "1to3", "3to5", "5to10", "gte10").contains(experienceRange))
            throw new ServiceException("工作经验筛选值不合法");
        city = trim(city);
        if (city != null && (city.length() > 50 || city.chars().anyMatch(Character::isISOControl)))
            throw new ServiceException("城市名称不合法");
        cityType = trim(cityType);
        if (cityType == null) cityType = "target";
        if (!List.of("current", "target").contains(cityType))
            throw new ServiceException("城市筛选类型不合法");
        if (loginWithinDays != null && !List.of(1, 3, 7, 14, 30, 90).contains(loginWithinDays))
            throw new ServiceException("最近登录筛选值不合法");
        referenceTime = LocalDateTime.now();
    }

    private String trim(String value) { return value == null || value.isBlank() ? null : value.trim(); }
    public Integer getMinimumEducation() { return minimumEducation; }
    public void setMinimumEducation(Integer value) { minimumEducation = value; }
    public String getExperienceRange() { return experienceRange; }
    public void setExperienceRange(String value) { experienceRange = value; }
    public String getCity() { return city; }
    public void setCity(String value) { city = value; }
    public String getCityType() { return cityType; }
    public void setCityType(String value) { cityType = value; }
    public Integer getLoginWithinDays() { return loginWithinDays; }
    public void setLoginWithinDays(Integer value) { loginWithinDays = value; }
    public LocalDateTime getReferenceTime() { return referenceTime; }
    public LocalDateTime getLoginSince() { return loginWithinDays == null ? null : referenceTime.minusDays(loginWithinDays); }
    public Integer getMinimumWorkMonths()
    {
        if (experienceRange == null) return null;
        return switch (experienceRange) { case "lt1" -> 0; case "1to3" -> 12;
            case "3to5" -> 36; case "5to10" -> 60; default -> 120; };
    }
    public Integer getMaximumWorkMonths()
    {
        if (experienceRange == null) return null;
        return switch (experienceRange) { case "lt1" -> 12; case "1to3" -> 36;
            case "3to5" -> 60; case "5to10" -> 120; default -> null; };
    }
}
