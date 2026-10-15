package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;

/**
 * 广告管理对象 t_ad
 *
 * @author TQY
 */
public class Ad
{
    private static final long serialVersionUID = 1L;

    /** 广告ID */
    private Long adId;

    /** 广告位编码 */
    private String adSlotCode;

    /** 广告标题 */
    private String adTitle;

    /** 广告类型 */
    private Integer adType;

    /** 广告媒体URL */
    private String adMediaUrl;

    /** 封面URL */
    private String adCoverUrl;

    /** 跳转URL */
    private String adJumpUrl;

    /** 目标用户 */
    private String adTargetUsers;

    /** 目标设备 */
    private String adTargetDevices;

    /** 每日频次 */
    private Integer adFreqDaily;

    /** 排序 */
    private Integer adSortOrder;

    /** 开始时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date adStartAt;

    /** 结束时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date adEndAt;

    /** 状态（1启用 0禁用） */
    private Integer adStatus;

    /** 创建时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date adCreatedAt;

    /** 更新时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date adUpdatedAt;

    public Long getAdId() { return adId; }
    public void setAdId(Long adId) { this.adId = adId; }

    public String getAdSlotCode() { return adSlotCode; }
    public void setAdSlotCode(String adSlotCode) { this.adSlotCode = adSlotCode; }

    public String getAdTitle() { return adTitle; }
    public void setAdTitle(String adTitle) { this.adTitle = adTitle; }

    public Integer getAdType() { return adType; }
    public void setAdType(Integer adType) { this.adType = adType; }

    public String getAdMediaUrl() { return adMediaUrl; }
    public void setAdMediaUrl(String adMediaUrl) { this.adMediaUrl = adMediaUrl; }

    public String getAdCoverUrl() { return adCoverUrl; }
    public void setAdCoverUrl(String adCoverUrl) { this.adCoverUrl = adCoverUrl; }

    public String getAdJumpUrl() { return adJumpUrl; }
    public void setAdJumpUrl(String adJumpUrl) { this.adJumpUrl = adJumpUrl; }

    public String getAdTargetUsers() { return adTargetUsers; }
    public void setAdTargetUsers(String adTargetUsers) { this.adTargetUsers = adTargetUsers; }

    public String getAdTargetDevices() { return adTargetDevices; }
    public void setAdTargetDevices(String adTargetDevices) { this.adTargetDevices = adTargetDevices; }

    public Integer getAdFreqDaily() { return adFreqDaily; }
    public void setAdFreqDaily(Integer adFreqDaily) { this.adFreqDaily = adFreqDaily; }

    public Integer getAdSortOrder() { return adSortOrder; }
    public void setAdSortOrder(Integer adSortOrder) { this.adSortOrder = adSortOrder; }

    public Date getAdStartAt() { return adStartAt; }
    public void setAdStartAt(Date adStartAt) { this.adStartAt = adStartAt; }

    public Date getAdEndAt() { return adEndAt; }
    public void setAdEndAt(Date adEndAt) { this.adEndAt = adEndAt; }

    public Integer getAdStatus() { return adStatus; }
    public void setAdStatus(Integer adStatus) { this.adStatus = adStatus; }

    public Date getAdCreatedAt() { return adCreatedAt; }
    public void setAdCreatedAt(Date adCreatedAt) { this.adCreatedAt = adCreatedAt; }

    public Date getAdUpdatedAt() { return adUpdatedAt; }
    public void setAdUpdatedAt(Date adUpdatedAt) { this.adUpdatedAt = adUpdatedAt; }
}
