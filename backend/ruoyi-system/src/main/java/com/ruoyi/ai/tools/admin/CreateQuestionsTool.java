package com.ruoyi.ai.tools.admin;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.AbstractAgentTool;
import com.ruoyi.ai.core.PendingAction;
import com.ruoyi.ai.core.PendingActionHandler;
import com.ruoyi.ai.core.ToolArgs;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;
import com.ruoyi.system.service.exam.IExamImportLogService;
import com.ruoyi.system.service.exam.IExamQuestionBankService;

/**
 * 生成待确认的题目草稿。
 *
 * <p>execute 只登记草稿、不落库；用户点卡片确认后才走 apply 真正写入并记批次。</p>
 */
@Component
public class CreateQuestionsTool extends AbstractAgentTool implements PendingActionHandler
{
    @Autowired
    private IExamQuestionBankService examQuestionBankService;

    @Autowired
    private IExamImportLogService examImportLogService;

    @Override
    public String name()
    {
        return "create_questions";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        props.putObject("bankType").put("type", "string").put("enum",
                json.createArrayNode().add("platform").add("enterprise"));
        props.putObject("companyId").put("type", "integer").put("description", "企业题库必填");
        ObjectNode itemsSchema = props.putObject("items");
        itemsSchema.put("type", "array").put("description", "题目数组，最多 50 条").put("maxItems", 50);
        ObjectNode itemProps = itemsSchema.putObject("items").put("type", "object").putObject("properties");
        itemProps.putObject("content").put("type", "string").put("description", "题干，必填");
        itemProps.putObject("type").put("type", "integer").put("minimum", 1).put("maximum", 5);
        itemProps.putObject("options").put("type", "array").put("description", "单选/多选的选项文本数组");
        itemProps.putObject("answer").put("type", "string").put("description", "答案，多选写 ABD");
        itemProps.putObject("analysis").put("type", "string");
        itemProps.putObject("score").put("type", "number");
        itemProps.putObject("difficulty").put("type", "integer").put("minimum", 1).put("maximum", 5);
        itemProps.putObject("category").put("type", "integer").put("minimum", 1).put("maximum", 5);
        itemsSchema.putArray("required").add("content");
        params.putArray("required").add("bankType").add("items");
        return toolDef("生成待确认的题目草稿（不直接入库，需用户点卡片确认）", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String bankType = ToolArgs.text(args, "bankType", 20);
        Long companyId = QuestionBankSupport.companyIdOf(bankType, args);
        JsonNode itemsNode = QuestionBankSupport.itemsNode(json, args);
        if (!itemsNode.isArray() || itemsNode.size() == 0)
        {
            return ToolResult.read("没有可创建的题目：items 为空。");
        }
        if (itemsNode.size() > QuestionBankSupport.MAX_ITEMS)
        {
            return ToolResult.read("一次最多创建 " + QuestionBankSupport.MAX_ITEMS + " 题，请分批提交。");
        }
        List<Map<String, Object>> items = new ArrayList<>();
        for (JsonNode node : itemsNode)
        {
            String content = node.path("content").asText("").trim();
            if (content.isEmpty())
            {
                continue;
            }
            if (content.length() > QuestionBankSupport.MAX_CONTENT)
            {
                content = content.substring(0, QuestionBankSupport.MAX_CONTENT);
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("content", content);
            item.put("type", node.has("type") ? node.path("type").asInt(1) : 1);
            item.put("typeName", node.has("typeName") ? node.path("typeName").asText("")
                    : QuestionBankSupport.TYPE_NAMES.getOrDefault(item.get("type"), "单选"));
            item.put("options", ToolArgs.textList(node.path("options")));
            item.put("answer", node.path("answer").asText(""));
            item.put("analysis", node.path("analysis").asText(""));
            item.put("score", node.has("score") ? node.path("score").asDouble(2) : 2);
            item.put("difficulty", node.has("difficulty") ? node.path("difficulty").asInt(1) : 1);
            item.put("category", node.has("category") ? node.path("category").asInt(1) : 1);
            items.add(item);
        }
        if (items.isEmpty())
        {
            return ToolResult.read("没有可创建的题目：所有条目 content 为空。");
        }

        PendingAction action = new PendingAction();
        action.put("items", items);
        action.put("companyId", companyId);
        register(ctx, QuestionBankSupport.SCOPE, "create", "待确认：新增题目", action);

        StringBuilder out = new StringBuilder();
        out.append("已生成 ").append(items.size()).append(" 题草稿（待确认，尚未入库）。\n");
        for (int i = 0; i < items.size(); i++)
        {
            Map<String, Object> item = items.get(i);
            out.append(i + 1).append(". “").append(ToolArgs.cut(String.valueOf(item.get("content")), 40)).append("”\n");
        }
        out.append("pendingId=").append(action.id).append("；请告诉用户点击卡片上的「确认入库」执行。");
        String text = out.toString();
        action.summary = QuestionBankSupport.summarize(text);
        return ToolResult.propose(text, action);
    }

    @Override
    public boolean supports(PendingAction action)
    {
        return "create".equals(action.kind) && QuestionBankSupport.SCOPE.equals(action.scope);
    }

    @Override
    public Map<String, Object> apply(PendingAction action, ToolContext ctx)
    {
        List<Map<String, Object>> items = action.get("items");
        Long companyId = action.get("companyId");
        Map<String, Object> data = examQuestionBankService.batchInsert(items, companyId);
        List<?> errors = (List<?>) data.get("errors");
        int failed = errors == null ? 0 : errors.size();
        @SuppressWarnings("unchecked")
        List<Long> savedIds = (List<Long>) data.get("ids");
        Object insertedObj = data.get("inserted");
        int inserted = insertedObj instanceof Number ? ((Number) insertedObj).intValue() : 0;
        Long batchId = examImportLogService.record(1, "AI 助手生成", companyId,
                items.size(), inserted, failed, savedIds, ctx.getOperator());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("kind", "create");
        result.put("inserted", inserted);
        result.put("failed", failed);
        result.put("errors", errors == null ? List.of() : errors);
        result.put("batchId", batchId);
        result.put("ids", savedIds == null ? List.of() : savedIds);
        return result;
    }
}
