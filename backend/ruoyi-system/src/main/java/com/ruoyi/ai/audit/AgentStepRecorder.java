package com.ruoyi.ai.audit;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.ruoyi.ai.core.ToolContext;

/**
 * 工具调用审计：每次工具执行落一条记录，用于回答"谁让模型改了什么"。
 *
 * <p>默认关闭（ai.agent.audit.enabled=false）。审计表 04_ai_agent_step.sql 执行后再打开，
 * 避免表不存在时刷屏报错。</p>
 *
 * <p>审计失败只吞异常记 debug，绝不影响主流程。</p>
 */
@Component
public class AgentStepRecorder
{
    private static final int MAX_TEXT = 500;

    private static final String INSERT_SQL =
            "INSERT INTO t_ai_agent_step (step_scope, step_user_id, step_user_name, step_tool, " +
            "step_args, step_result, step_status, step_cost_ms, step_pending_id) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

    @Autowired
    private JdbcTemplate jdbc;

    @Value("${ai.agent.audit.enabled:false}")
    private boolean enabled;

    /**
     * @param status    0 成功，1 失败
     * @param pendingId 写提案产生的待确认编号，只读工具传 null
     */
    public void record(ToolContext ctx, String tool, String args, String result,
            int status, long costMs, String pendingId)
    {
        if (!enabled)
        {
            return;
        }
        try
        {
            jdbc.update(INSERT_SQL,
                    ctx == null ? "admin" : ctx.getScope(),
                    ctx == null ? null : ctx.getUserId(),
                    ctx == null ? "system" : ctx.getOperator(),
                    tool,
                    cut(args),
                    cut(result),
                    status,
                    (int) Math.min(costMs, Integer.MAX_VALUE),
                    pendingId);
        }
        catch (Exception ignore)
        {
            // 审计写失败不影响业务
        }
    }

    private static String cut(String text)
    {
        if (text == null)
        {
            return null;
        }
        return text.length() <= MAX_TEXT ? text : text.substring(0, MAX_TEXT);
    }
}
