package com.ruoyi.system.domain.app;

/** C-App AI 简历推荐结果：岗位卡片 + 推荐理由。 */
public class AppJobRecommendation extends AppJob
{
    private static final long serialVersionUID = 1L;

    private String reason;

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
}
