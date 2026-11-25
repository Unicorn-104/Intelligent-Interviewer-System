package com.ruoyi.ai.tools.admin;

import java.util.ArrayList;
import java.util.LinkedHashMap;
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
import com.ruoyi.ai.core.ToolArgs;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

/**
 * 生成待确认的企业录入草稿。
 *
 * <p>execute 只做字段整理与同名预检，不落库；用户点卡片确认后才写入 t_cmp，
 * 默认认证状态为未认证、状态为正常，避免绕过企业认证流程。</p>
 */
@Component
public class CreateCompaniesTool extends AbstractAgentTool implements PendingActionHandler
{
    private static final int MAX_ITEMS = 20;

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "create_companies";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        ObjectNode items = props.putObject("items");
        items.put("type", "array").put("description", "企业数组，最多 20 家").put("maxItems", MAX_ITEMS);
        ObjectNode itemSchema = items.putObject("items");
        itemSchema.put("type", "object");
        ObjectNode itemProps = itemSchema.putObject("properties");
        itemProps.putObject("name").put("type", "string").put("description", "企业全称，必填");
        itemProps.putObject("creditCode").put("type", "string").put("description", "统一社会信用代码");
        itemProps.putObject("industry").put("type", "string");
        itemProps.putObject("size").put("type", "string").put("description", "企业规模，如 100-499 人");
        itemProps.putObject("city").put("type", "string");
        itemProps.putObject("address").put("type", "string");
        itemProps.putObject("website").put("type", "string");
        itemProps.putObject("intro").put("type", "string");
        itemProps.putObject("contactName").put("type", "string");
        itemProps.putObject("contactPhone").put("type", "string");
        itemSchema.putArray("required").add("name");
        params.putArray("required").add("items");
        return toolDef("生成待确认的企业信息录入草稿（不直接入库，需用户点卡片确认）。"
                + "用户要求把文件或文本里的公司信息录入系统时调用；同名企业会被跳过。", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        JsonNode itemsNode = args.path("items");
        if (!itemsNode.isArray() || itemsNode.size() == 0)
        {
            return ToolResult.read("没有可录入的企业：items 为空。");
        }
        if (itemsNode.size() > MAX_ITEMS)
        {
            return ToolResult.read("一次最多录入 " + MAX_ITEMS + " 家企业，请分批提交。");
        }

        List<Map<String, Object>> items = new ArrayList<>();
        List<String> duplicated = new ArrayList<>();
        for (JsonNode node : itemsNode)
        {
            String name = ToolArgs.text(node, "name", 100);
            if (name.isEmpty())
            {
                continue;
            }
            if (exists(name))
            {
                duplicated.add(name);
                continue;
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("name", name);
            item.put("creditCode", ToolArgs.text(node, "creditCode", 50));
            item.put("industry", ToolArgs.text(node, "industry", 50));
            item.put("size", ToolArgs.text(node, "size", 30));
            item.put("city", ToolArgs.text(node, "city", 50));
            item.put("address", ToolArgs.text(node, "address", 200));
            item.put("website", ToolArgs.text(node, "website", 200));
            item.put("intro", ToolArgs.text(node, "intro", 500));
            item.put("contactName", ToolArgs.text(node, "contactName", 50));
            item.put("contactPhone", ToolArgs.text(node, "contactPhone", 30));
            items.add(item);
        }
        if (items.isEmpty())
        {
            String reason = duplicated.isEmpty()
                    ? "没有可录入的企业：所有条目 name 为空。"
                    : "这些企业已存在，未生成草稿：" + String.join("、", duplicated);
            return ToolResult.read(reason);
        }

        PendingAction action = new PendingAction();
        action.put("items", items);
        register(ctx, QuestionBankSupport.SCOPE, "create_companies", "待确认：录入企业", action);

        StringBuilder out = new StringBuilder();
        out.append("已生成 ").append(items.size()).append(" 家企业草稿（待确认，尚未入库）。\n");
        for (int i = 0; i < items.size(); i++)
        {
            out.append(i + 1).append(". ").append(items.get(i).get("name")).append('\n');
        }
        if (!duplicated.isEmpty())
        {
            out.append("已跳过 ").append(duplicated.size()).append(" 家同名企业：")
                    .append(String.join("、", duplicated)).append('\n');
        }
        out.append("pendingId=").append(action.id).append("；请告诉用户点击卡片上的「确认执行」写入。");
        String text = out.toString();
        action.summary = QuestionBankSupport.summarize(text);
        return ToolResult.propose(text, action);
    }

    @Override
    public boolean supports(PendingAction action)
    {
        return "create_companies".equals(action.kind) && QuestionBankSupport.SCOPE.equals(action.scope);
    }

    @Override
    public Map<String, Object> apply(PendingAction action, ToolContext ctx)
    {
        List<Map<String, Object>> items = action.get("items");
        int inserted = 0;
        List<String> skipped = new ArrayList<>();
        List<String> errors = new ArrayList<>();
        for (Map<String, Object> item : items)
        {
            String name = String.valueOf(item.get("name"));
            if (exists(name))
            {
                skipped.add(name);
                continue;
            }
            try
            {
                jdbc.update("INSERT INTO t_cmp (cmp_name, cmp_credit_code, cmp_industry, cmp_size, cmp_city, "
                        + "cmp_address, cmp_website, cmp_intro, contact_name, contact_phone, "
                        + "cmp_verify_status, cmp_status, cmp_created_at) "
                        + "VALUES (?,?,?,?,?,?,?,?,?,?,0,1,NOW())",
                        name, item.get("creditCode"), item.get("industry"), item.get("size"),
                        item.get("city"), item.get("address"), item.get("website"), item.get("intro"),
                        item.get("contactName"), item.get("contactPhone"));
                inserted++;
            }
            catch (Exception e)
            {
                errors.add(name + "：" + e.getMessage());
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("kind", "create_companies");
        result.put("inserted", inserted);
        result.put("skipped", skipped);
        result.put("errors", errors);
        return result;
    }

    private boolean exists(String name)
    {
        Integer count = jdbc.queryForObject("SELECT COUNT(1) FROM t_cmp WHERE cmp_name=?", Integer.class, name);
        return count != null && count > 0;
    }
}
