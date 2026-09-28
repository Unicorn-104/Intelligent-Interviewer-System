package com.ruoyi.system.domain;

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

    public Long getPmvId() { return pmvId; }
    public void setPmvId(Long pmvId) { this.pmvId = pmvId; }
    public String getPmvName() { return pmvName; }
    public void setPmvName(String pmvName) { this.pmvName = pmvName; }
    public String getPmvContent() { return pmvContent; }
    public void setPmvContent(String pmvContent) { this.pmvContent = pmvContent; }
    public String getPmvVariablesJson() { return pmvVariablesJson; }
    public void setPmvVariablesJson(String pmvVariablesJson) { this.pmvVariablesJson = pmvVariablesJson; }
}
