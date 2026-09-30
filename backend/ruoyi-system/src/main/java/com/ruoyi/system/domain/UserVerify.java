package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 用户实名认证对象 t_usr_verify
 *
 * @author TQY
 */
public class UserVerify extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 认证ID */
    private Long vefId;

    /** 用户ID */
    private Long vefUserId;

    /** 真实姓名 */
    private String vefRealName;

    /** 身份证号 */
    private String vefIdCard;

    /** 身份证正面照URL */
    private String vefFrontImg;

    /** 身份证背面照URL */
    private String vefBackImg;

    /** 状态：0-待审核，1-已通过，2-已拒绝 */
    private Integer vefStatus;

    /** 拒绝原因 */
    private String vefRejectReason;

    /** 提交时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date vefCreatedAt;

    /** 审核通过时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date vefVerifiedAt;

    public Long getVefId() { return vefId; }
    public void setVefId(Long vefId) { this.vefId = vefId; }
    public Long getVefUserId() { return vefUserId; }
    public void setVefUserId(Long vefUserId) { this.vefUserId = vefUserId; }
    public String getVefRealName() { return vefRealName; }
    public void setVefRealName(String vefRealName) { this.vefRealName = vefRealName; }
    public String getVefIdCard() { return vefIdCard; }
    public void setVefIdCard(String vefIdCard) { this.vefIdCard = vefIdCard; }
    public String getVefFrontImg() { return vefFrontImg; }
    public void setVefFrontImg(String vefFrontImg) { this.vefFrontImg = vefFrontImg; }
    public String getVefBackImg() { return vefBackImg; }
    public void setVefBackImg(String vefBackImg) { this.vefBackImg = vefBackImg; }
    public Integer getVefStatus() { return vefStatus; }
    public void setVefStatus(Integer vefStatus) { this.vefStatus = vefStatus; }
    public String getVefRejectReason() { return vefRejectReason; }
    public void setVefRejectReason(String vefRejectReason) { this.vefRejectReason = vefRejectReason; }
    public Date getVefCreatedAt() { return vefCreatedAt; }
    public void setVefCreatedAt(Date vefCreatedAt) { this.vefCreatedAt = vefCreatedAt; }
    public Date getVefVerifiedAt() { return vefVerifiedAt; }
    public void setVefVerifiedAt(Date vefVerifiedAt) { this.vefVerifiedAt = vefVerifiedAt; }
}
