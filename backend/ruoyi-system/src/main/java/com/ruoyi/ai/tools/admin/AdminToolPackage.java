package com.ruoyi.ai.tools.admin;

import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Component;

import com.ruoyi.ai.core.AgentTool;
import com.ruoyi.ai.core.AgentToolPackage;
import com.ruoyi.ai.mcp.McpToolRegistry;

/**
 * 管理端工具包。新增管理端工具时在这里登记一次即可，编排层无需改动。
 *
 * <p>显式构造注入而不是注入 List&lt;AgentTool&gt;：避免把其他端的工具混进本端。</p>
 */
@Component
public class AdminToolPackage implements AgentToolPackage
{
    private final List<AgentTool> baseTools;

    private final McpToolRegistry mcpRegistry;

    public AdminToolPackage(GetDashboardStatsTool dashboardStats,
            GetRecentLoginAlertsTool loginAlerts,
            SearchQuestionsTool searchQuestions,
            GetQuestionDetailTool questionDetail,
            CheckDuplicateQuestionsTool checkDuplicates,
            GetQuestionStatsTool questionStats,
            ListImportBatchesTool listBatches,
            CreateQuestionsTool createQuestions,
            ClassifyQuestionsTool classifyQuestions,
            UpdateQuestionsTool updateQuestions,
            DeleteQuestionsTool deleteQuestions,
            UndoImportBatchTool undoImportBatch,
            CreateCompaniesTool createCompanies,
            SearchJobsTool searchJobs,
            SearchTalentTool searchTalent,
            ListMessageTemplatesTool listMessageTemplates,
            McpToolRegistry mcpRegistry)
    {
        this.baseTools = List.of(dashboardStats, loginAlerts, searchQuestions, questionDetail, checkDuplicates,
                questionStats, listBatches, createQuestions, classifyQuestions, updateQuestions,
                deleteQuestions, undoImportBatch, createCompanies, searchJobs, searchTalent, listMessageTemplates);
        this.mcpRegistry = mcpRegistry;
    }

    @Override
    public String scope()
    {
        return QuestionBankSupport.SCOPE;
    }

    @Override
    public List<AgentTool> tools()
    {
        List<AgentTool> mcpTools = mcpRegistry.tools();
        if (mcpTools.isEmpty())
        {
            return baseTools;
        }
        List<AgentTool> all = new ArrayList<>(baseTools);
        all.addAll(mcpTools);
        return all;
    }
}
