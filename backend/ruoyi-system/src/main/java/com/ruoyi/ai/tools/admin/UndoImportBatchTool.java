package com.ruoyi.ai.tools.admin;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.AbstractAgentTool;
import com.ruoyi.ai.core.PendingAction;
import com.ruoyi.ai.core.PendingActionHandler;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;
import com.ruoyi.system.service.exam.IExamImportLogService;

/** 撤销某次题库导入批次：先出草稿，确认后才删除未被引用的题。 */
@Component
public class UndoImportBatchTool extends AbstractAgentTool implements PendingActionHandler
{
    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private IExamImportLogService examImportLogService;

    @Override
    public String name()
    {
        return "undo_import_batch";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        params.putObject("properties").putObject("batchId").put("type", "integer");
        params.putArray("required").add("batchId");
        return toolDef("撤销某次题库导入批次（生成待确认草稿）", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        Long batchId = args.has("batchId") ? args.path("batchId").asLong(0) : 0L;
        if (batchId <= 0)
        {
            return ToolResult.read("请提供要撤销的批次号 batchId，可先用 list_import_batches 查看。");
        }
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT eqb_status AS status, eqb_inserted AS inserted, eqb_total AS total, "
                + "eqb_file_name AS fileName FROM t_exam_question_import_batch WHERE eqb_id = ?", batchId);
        if (rows.isEmpty())
        {
            return ToolResult.read("批次 #" + batchId + " 不存在。");
        }
        Map<String, Object> row = rows.get(0);
        int status = ((Number) row.get("status")).intValue();
        if (status == 1)
        {
            return ToolResult.read("批次 #" + batchId + " 已撤销过，不能重复操作。");
        }

        PendingAction action = new PendingAction();
        action.put("batchId", batchId);
        register(ctx, QuestionBankSupport.SCOPE, "undo", "待确认：撤销导入批次", action);

        String text = "将撤销批次 #" + batchId + "（成功 " + row.get("inserted") + "/" + row.get("total")
                + " 题" + (row.get("fileName") == null ? "" : "，文件「" + row.get("fileName") + "」")
                + "）。只删除仍存在且未被考卷引用的题。pendingId=" + action.id + "；请让用户点击卡片确认。";
        action.summary = QuestionBankSupport.summarize(text);
        return ToolResult.propose(text, action);
    }

    @Override
    public boolean supports(PendingAction action)
    {
        return "undo".equals(action.kind) && QuestionBankSupport.SCOPE.equals(action.scope);
    }

    @Override
    public Map<String, Object> apply(PendingAction action, ToolContext ctx)
    {
        Long batchId = action.get("batchId");
        return examImportLogService.undo(batchId, ctx.getOperator());
    }
}
