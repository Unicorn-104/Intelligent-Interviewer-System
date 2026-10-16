package com.ruoyi.system.domain.app;

import java.io.Serializable;
import jakarta.validation.constraints.NotNull;

/** C-App AI 简历推荐请求。 */
public class AppRecommendRequest implements Serializable
{
    private static final long serialVersionUID = 1L;

    @NotNull(message = "请选择简历")
    private Long resumeId;

    private String keyword;
    private String filter;
    private Integer limit;
    private Integer poolSize;

    public Long getResumeId() { return resumeId; }
    public void setResumeId(Long resumeId) { this.resumeId = resumeId; }
    public String getKeyword() { return keyword; }
    public void setKeyword(String keyword) { this.keyword = keyword; }
    public String getFilter() { return filter; }
    public void setFilter(String filter) { this.filter = filter; }
    public Integer getLimit() { return limit; }
    public void setLimit(Integer limit) { this.limit = limit; }
    public Integer getPoolSize() { return poolSize; }
    public void setPoolSize(Integer poolSize) { this.poolSize = poolSize; }
}
