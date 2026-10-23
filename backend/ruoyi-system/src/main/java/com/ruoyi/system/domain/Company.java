package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 企业信息对象 t_cmp
 *
 * @author TQY
 */
public class Company extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 企业ID */
    private Long cmpId;

    /** 企业全称 */
    private String cmpName;

    /** 统一社会信用代码 */
    private String cmpCreditCode;

    /** 企业Logo URL */
    private String cmpLogoUrl;

    /** 所属行业 */
    private String cmpIndustry;

    /** 企业规模 */
    private String cmpSize;

    /** 所在城市 */
    private String cmpCity;

    /** 详细地址 */
    private String cmpAddress;

    /** 官网 */
    private String cmpWebsite;

    /** 企业简介 */
    private String cmpIntro;

    /** 扩展详情JSON */
    private String cmpDetailJson;

    /** 企业认证状态：0-未认证，1-已认证，2-认证失败 */
    private Integer cmpVerifyStatus;

    /** 认证审核时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date cmpVerifyAt;

    /** 认证审核人ID */
    private Long cmpVerifyBy;

    /** 审核驳回理由 */
    private String verifyRemark;

    /** 状态：0-已下架，1-正常 */
    private Integer cmpStatus;

    /** API配额(次/月) */
    private Integer apiQuota;

    /** API已使用量 */
    private Integer apiUsed;

    /** 认证联系人 */
    private String contactName;

    /** 联系人电话 */
    private String contactPhone;

    /** 套餐类型 basic/pro/flag */
    private String packageType;

    /** 套餐到期日期 */
    @JsonFormat(pattern = "yyyy-MM-dd")
    private Date expireDate;

    /** 创建时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date cmpCreatedAt;

    public Long getCmpId() { return cmpId; }
    public void setCmpId(Long cmpId) { this.cmpId = cmpId; }
    public String getCmpName() { return cmpName; }
    public void setCmpName(String cmpName) { this.cmpName = cmpName; }
    public String getCmpCreditCode() { return cmpCreditCode; }
    public void setCmpCreditCode(String cmpCreditCode) { this.cmpCreditCode = cmpCreditCode; }
    public String getCmpLogoUrl() { return cmpLogoUrl; }
    public void setCmpLogoUrl(String cmpLogoUrl) { this.cmpLogoUrl = cmpLogoUrl; }
    public String getCmpIndustry() { return cmpIndustry; }
    public void setCmpIndustry(String cmpIndustry) { this.cmpIndustry = cmpIndustry; }
    public String getCmpSize() { return cmpSize; }
    public void setCmpSize(String cmpSize) { this.cmpSize = cmpSize; }
    public String getCmpCity() { return cmpCity; }
    public void setCmpCity(String cmpCity) { this.cmpCity = cmpCity; }
    public String getCmpAddress() { return cmpAddress; }
    public void setCmpAddress(String cmpAddress) { this.cmpAddress = cmpAddress; }
    public String getCmpWebsite() { return cmpWebsite; }
    public void setCmpWebsite(String cmpWebsite) { this.cmpWebsite = cmpWebsite; }
    public String getCmpIntro() { return cmpIntro; }
    public void setCmpIntro(String cmpIntro) { this.cmpIntro = cmpIntro; }
    public String getCmpDetailJson() { return cmpDetailJson; }
    public void setCmpDetailJson(String cmpDetailJson) { this.cmpDetailJson = cmpDetailJson; }
    public Integer getCmpVerifyStatus() { return cmpVerifyStatus; }
    public void setCmpVerifyStatus(Integer cmpVerifyStatus) { this.cmpVerifyStatus = cmpVerifyStatus; }
    public Date getCmpVerifyAt() { return cmpVerifyAt; }
    public void setCmpVerifyAt(Date cmpVerifyAt) { this.cmpVerifyAt = cmpVerifyAt; }
    public Long getCmpVerifyBy() { return cmpVerifyBy; }
    public void setCmpVerifyBy(Long cmpVerifyBy) { this.cmpVerifyBy = cmpVerifyBy; }
    public String getVerifyRemark() { return verifyRemark; }
    public void setVerifyRemark(String verifyRemark) { this.verifyRemark = verifyRemark; }
    public Integer getCmpStatus() { return cmpStatus; }
    public void setCmpStatus(Integer cmpStatus) { this.cmpStatus = cmpStatus; }

    public Integer getApiQuota() { return apiQuota; }
    public void setApiQuota(Integer apiQuota) { this.apiQuota = apiQuota; }

    public Integer getApiUsed() { return apiUsed; }
    public void setApiUsed(Integer apiUsed) { this.apiUsed = apiUsed; }
    public String getContactName() { return contactName; }
    public void setContactName(String contactName) { this.contactName = contactName; }
    public String getContactPhone() { return contactPhone; }
    public void setContactPhone(String contactPhone) { this.contactPhone = contactPhone; }
    public String getPackageType() { return packageType; }
    public void setPackageType(String packageType) { this.packageType = packageType; }
    public Date getExpireDate() { return expireDate; }
    public void setExpireDate(Date expireDate) { this.expireDate = expireDate; }
    public Date getCmpCreatedAt() { return cmpCreatedAt; }
    public void setCmpCreatedAt(Date cmpCreatedAt) { this.cmpCreatedAt = cmpCreatedAt; }
}
