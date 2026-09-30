package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * Prompt版本对象 t_prompt_version
 *
 * @author TQY
 */
public class PromptVersion extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** Prompt版本ID */
    private Long pmvId;

    /** Prompt名称 */
    private String pmvName;

    /** Prompt内容 */
    private String pmvContent;

    /** 变量定义JSON */
    private String pmvVariablesJson;

    /** 版本号 */
    private String pmvVersion;

    /** 状态：0-禁用，1-启用 */
    private Integer pmvStatus;

    /** 创建时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date pmvCreatedAt;

    /** 更新时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date pmvUpdatedAt;

    public Long getPmvId() { return pmvId; }
    public void setPmvId(Long pmvId) { this.pmvId = pmvId; }
    public String getPmvName() { return pmvName; }
    public void setPmvName(String pmvName) { this.pmvName = pmvName; }
    public String getPmvContent() { return pmvContent; }
    public void setPmvContent(String pmvContent) { this.pmvContent = pmvContent; }
    public String getPmvVariablesJson() { return pmvVariablesJson; }
    public void setPmvVariablesJson(String pmvVariablesJson) { this.pmvVariablesJson = pmvVariablesJson; }
    public String getPmvVersion() { return pmvVersion; }
    public void setPmvVersion(String pmvVersion) { this.pmvVersion = pmvVersion; }
    public Integer getPmvStatus() { return pmvStatus; }
    public void setPmvStatus(Integer pmvStatus) { this.pmvStatus = pmvStatus; }
    public Date getPmvCreatedAt() { return pmvCreatedAt; }
    public void setPmvCreatedAt(Date pmvCreatedAt) { this.pmvCreatedAt = pmvCreatedAt; }
    public Date getPmvUpdatedAt() { return pmvUpdatedAt; }
    public void setPmvUpdatedAt(Date pmvUpdatedAt) { this.pmvUpdatedAt = pmvUpdatedAt; }
}
