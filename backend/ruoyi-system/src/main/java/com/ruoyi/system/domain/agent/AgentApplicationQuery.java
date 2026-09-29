package com.ruoyi.system.domain.agent;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

/**
 * 投递记录查询参数。
 */
public class AgentApplicationQuery
{
    private String status;

    @Min(1)
    private Integer page = 1;

    @Min(1)
    @Max(100)
    private Integer size = 10;

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Integer getPage() { return page; }
    public void setPage(Integer page) { this.page = page; }
    public Integer getSize() { return size; }
    public void setSize(Integer size) { this.size = size; }
}
