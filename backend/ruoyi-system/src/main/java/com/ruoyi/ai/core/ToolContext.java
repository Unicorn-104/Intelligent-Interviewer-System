package com.ruoyi.ai.core;

/**
 * 一次工具调用的执行上下文。
 *
 * <p>只携带"谁在哪个端调用"，不携带请求对象，避免工具层依赖 web 模块。</p>
 */
public class ToolContext
{
    /** 所属端：admin / enterprise / seeker / exam。 */
    private final String scope;

    /** 操作人账号，用于批次台账与审计。 */
    private final String operator;

    private final Long userId;

    /** 企业端调用时的企业隔离边界；管理端为 null。 */
    private final Long companyId;

    public ToolContext(String scope, String operator, Long userId, Long companyId)
    {
        this.scope = scope;
        this.operator = operator == null || operator.isBlank() ? "system" : operator;
        this.userId = userId;
        this.companyId = companyId;
    }

    public static ToolContext of(String scope, String operator)
    {
        return new ToolContext(scope, operator, null, null);
    }

    public String getScope()
    {
        return scope;
    }

    public String getOperator()
    {
        return operator;
    }

    public Long getUserId()
    {
        return userId;
    }

    public Long getCompanyId()
    {
        return companyId;
    }
}
