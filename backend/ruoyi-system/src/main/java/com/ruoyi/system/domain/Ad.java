package com.ruoyi.system.domain;

import java.math.BigDecimal;
import java.util.List;
import com.ruoyi.common.core.domain.BaseEntity;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 广告管理对象 t_ad
 *
 * @author TQY
 */
public class Ad extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 广告ID */
    private Long advertId;

    /** 广告标题 */
    @NotBlank(message = "广告标题不能为空")
    private String title;

    /** 广告位ID */
    @NotBlank(message = "所属广告位不能为空")
    private String slotId;

    /** 广告类型（image图片 video视频 rich富文本） */
    @NotBlank(message = "广告类型不能为空")
    private String adType;

    /** 素材URL */
    private String mediaUrl;

    /** 富文本内容 */
    private String richContent;

    /** 跳转类型（none无跳转 h5H5链接 miniapp小程序 appApp内页面） */
    private String jumpType;

    /** 跳转地址 */
    private String jumpUrl;

    /** 开始时间 */
    @NotBlank(message = "开始时间不能为空")
    private String startTime;

    /** 结束时间 */
    @NotBlank(message = "结束时间不能为空")
    private String endTime;

    /** 每日展示频次 */
    private Integer dailyLimit;

    /** 总曝光上限 */
    private Integer totalLimit;

    /** 目标套餐 */
    private List<String> packageTarget;

    /** 曝光次数 */
    private Long exposure;

    /** 点击次数 */
    private Long clicks;

    /** 点击率 */
    private BigDecimal ctr;

    /** 状态（0草稿 1进行中 2暂停 3已结束） */
    private String status;

    /** 广告位名称（关联查询用） */
    private String slotName;

    public Long getAdvertId() { return advertId; }
    public void setAdvertId(Long advertId) { this.advertId = advertId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getSlotId() { return slotId; }
    public void setSlotId(String slotId) { this.slotId = slotId; }

    public String getAdType() { return adType; }
    public void setAdType(String adType) { this.adType = adType; }

    public String getMediaUrl() { return mediaUrl; }
    public void setMediaUrl(String mediaUrl) { this.mediaUrl = mediaUrl; }

    public String getRichContent() { return richContent; }
    public void setRichContent(String richContent) { this.richContent = richContent; }

    public String getJumpType() { return jumpType; }
    public void setJumpType(String jumpType) { this.jumpType = jumpType; }

    public String getJumpUrl() { return jumpUrl; }
    public void setJumpUrl(String jumpUrl) { this.jumpUrl = jumpUrl; }

    public String getStartTime() { return startTime; }
    public void setStartTime(String startTime) { this.startTime = startTime; }

    public String getEndTime() { return endTime; }
    public void setEndTime(String endTime) { this.endTime = endTime; }

    public Integer getDailyLimit() { return dailyLimit; }
    public void setDailyLimit(Integer dailyLimit) { this.dailyLimit = dailyLimit; }

    public Integer getTotalLimit() { return totalLimit; }
    public void setTotalLimit(Integer totalLimit) { this.totalLimit = totalLimit; }

    public List<String> getPackageTarget() { return packageTarget; }
    public void setPackageTarget(List<String> packageTarget) { this.packageTarget = packageTarget; }

    public Long getExposure() { return exposure; }
    public void setExposure(Long exposure) { this.exposure = exposure; }

    public Long getClicks() { return clicks; }
    public void setClicks(Long clicks) { this.clicks = clicks; }

    public BigDecimal getCtr() { return ctr; }
    public void setCtr(BigDecimal ctr) { this.ctr = ctr; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getSlotName() { return slotName; }
    public void setSlotName(String slotName) { this.slotName = slotName; }
}
