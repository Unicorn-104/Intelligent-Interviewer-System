package com.ruoyi.common.enums;

/**
 * 岗位投递终止原因（t_app_record.end_reason）。
 *
 * <p>仅当 app_status = 5（未录用）时才允许填写；终止原因独立成字段，
 * 不得为每种原因新增一个招聘阶段，也不得混入 app_status。</p>
 *
 * @author tqy
 */
public enum ApplicationEndReason
{
    /** HR 主动淘汰（必须记录操作人） */
    HR_REJECTED("HR 主动淘汰"),

    /** 候选人主动撤回岗位投递 */
    CANDIDATE_WITHDRAWN("候选人主动撤回"),

    /** 候选人拒绝 Offer */
    OFFER_REJECTED("候选人拒绝 Offer"),

    /** Offer 超过有效期限 */
    OFFER_EXPIRED("Offer 过期"),

    /** HR 取消已发放的 Offer */
    OFFER_CANCELLED("HR 取消已发放的 Offer"),

    /** 历史数据：旧版 AI 初筛淘汰，仅用于迁移标记，新业务不得再执行 AI 自动淘汰 */
    LEGACY_SCREENING_REJECTED("历史 AI 初筛淘汰");

    private final String label;

    ApplicationEndReason(String label)
    {
        this.label = label;
    }

    public String getLabel()
    {
        return label;
    }

    /** 编码即枚举名，落库为字符串，保证可读且与迁移脚本口径一致 */
    public String getCode()
    {
        return name();
    }

    public static ApplicationEndReason fromCode(String code)
    {
        if (code == null || code.isBlank()) return null;
        for (ApplicationEndReason reason : values())
        {
            if (reason.name().equals(code)) return reason;
        }
        return null;
    }
}
