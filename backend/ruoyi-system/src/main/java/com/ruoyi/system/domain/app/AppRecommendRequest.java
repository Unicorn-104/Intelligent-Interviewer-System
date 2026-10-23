package com.ruoyi.system.domain.app;

import java.io.Serializable;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/** C-App AI 简历推荐请求。 */
public class AppRecommendRequest implements Serializable
{
    private static final long serialVersionUID = 1L;

    @NotNull(message = "请选择简历")
    @Positive(message = "简历编号无效")
    private Long resumeId;

    @Size(max = 100, message = "关键词不能超过100个字符")
    private String keyword;
    @Size(max = 20, message = "筛选条件无效")
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
