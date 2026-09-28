package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 告警记录对象 t_sys_alert
 *
 * @author TQY
 */
public class SysAlert extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 告警ID */
    private Long salId;

    /** 告警类型 */
    private String salAlertType;

    /** 级别：1-低，2-中，3-高，4-紧急 */
    private Integer salLevel;

    /** 告警内容 */
    private String salContent;

    /** 处理状态：0-未处理，1-已处理 */
    private Integer salStatus;

    /** 处理时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date salHandledAt;

    /** 创建时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date salCreatedAt;

    /** 更新时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date salUpdatedAt;

    public Long getSalId() { return salId; }
    public void setSalId(Long salId) { this.salId = salId; }
    public String getSalAlertType() { return salAlertType; }
    public void setSalAlertType(String salAlertType) { this.salAlertType = salAlertType; }
    public Integer getSalLevel() { return salLevel; }
    public void setSalLevel(Integer salLevel) { this.salLevel = salLevel; }
    public String getSalContent() { return salContent; }
    public void setSalContent(String salContent) { this.salContent = salContent; }
    public Integer getSalStatus() { return salStatus; }
    public void setSalStatus(Integer salStatus) { this.salStatus = salStatus; }
    public Date getSalHandledAt() { return salHandledAt; }
    public void setSalHandledAt(Date salHandledAt) { this.salHandledAt = salHandledAt; }
    public Date getSalCreatedAt() { return salCreatedAt; }
    public void setSalCreatedAt(Date salCreatedAt) { this.salCreatedAt = salCreatedAt; }
    public Date getSalUpdatedAt() { return salUpdatedAt; }
    public void setSalUpdatedAt(Date salUpdatedAt) { this.salUpdatedAt = salUpdatedAt; }
}
