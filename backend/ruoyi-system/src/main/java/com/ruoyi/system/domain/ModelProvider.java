package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * 模型Provider配置对象 t_model_provider
 *
 * @author TQY
 */
public class ModelProvider extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** Provider ID */
    private Long mppId;

    /** Provider名称 */
    private String mppName;

    /** API地址 */
    private String mppApiUrl;

    /** 密钥 */
    private String mppApiKey;

    /** 模型名 */
    private String mppModelName;

    /** 参数JSON */
    private String mppParamsJson;

    /** 状态：0-禁用，1-启用 */
    private Integer mppStatus;

    /** 创建时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date mppCreatedAt;

    /** 更新时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date mppUpdatedAt;

    public Long getMppId() { return mppId; }
    public void setMppId(Long mppId) { this.mppId = mppId; }
    public String getMppName() { return mppName; }
    public void setMppName(String mppName) { this.mppName = mppName; }
    public String getMppApiUrl() { return mppApiUrl; }
    public void setMppApiUrl(String mppApiUrl) { this.mppApiUrl = mppApiUrl; }
    public String getMppApiKey() { return mppApiKey; }
    public void setMppApiKey(String mppApiKey) { this.mppApiKey = mppApiKey; }
    public String getMppModelName() { return mppModelName; }
    public void setMppModelName(String mppModelName) { this.mppModelName = mppModelName; }
    public String getMppParamsJson() { return mppParamsJson; }
    public void setMppParamsJson(String mppParamsJson) { this.mppParamsJson = mppParamsJson; }
    public Integer getMppStatus() { return mppStatus; }
    public void setMppStatus(Integer mppStatus) { this.mppStatus = mppStatus; }
    public Date getMppCreatedAt() { return mppCreatedAt; }
    public void setMppCreatedAt(Date mppCreatedAt) { this.mppCreatedAt = mppCreatedAt; }
    public Date getMppUpdatedAt() { return mppUpdatedAt; }
    public void setMppUpdatedAt(Date mppUpdatedAt) { this.mppUpdatedAt = mppUpdatedAt; }
}
