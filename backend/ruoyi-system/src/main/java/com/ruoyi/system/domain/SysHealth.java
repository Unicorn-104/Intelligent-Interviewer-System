package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 服务健康监控对象 t_sys_health
 *
 * @author TQY
 */
public class SysHealth extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 监控记录ID */
    private Long sthId;

    /** 服务名称 */
    private String sthServiceName;

    /** 状态：0-异常，1-正常，2-降级 */
    private Integer sthStatus;

    /** 响应时间（毫秒） */
    private Integer sthResponseTimeMs;

    /** 监控时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date sthCheckTime;

    public Long getSthId() { return sthId; }
    public void setSthId(Long sthId) { this.sthId = sthId; }
    public String getSthServiceName() { return sthServiceName; }
    public void setSthServiceName(String sthServiceName) { this.sthServiceName = sthServiceName; }
    public Integer getSthStatus() { return sthStatus; }
    public void setSthStatus(Integer sthStatus) { this.sthStatus = sthStatus; }
    public Integer getSthResponseTimeMs() { return sthResponseTimeMs; }
    public void setSthResponseTimeMs(Integer sthResponseTimeMs) { this.sthResponseTimeMs = sthResponseTimeMs; }
    public Date getSthCheckTime() { return sthCheckTime; }
    public void setSthCheckTime(Date sthCheckTime) { this.sthCheckTime = sthCheckTime; }
}
