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
 * 生成待确认的岗位录入草稿。
 *
 * <p>execute 只做字段整理与企业/重复预检，不落库；用户点卡片确认后才写入 t_pos。
 * 入库默认 pos_status=2（未上架），避免管理端代录直接改变求职者端可见岗位。</p>
 */
@Component
public class CreatePositionsTool extends AbstractAgentTool implements PendingActionHandler
{
    private static final int MAX_ITEMS = 20;

    /** 默认未上架，需在岗位管理页人工上架。 */
    private static final int DEFAULT_STATUS = 2;

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "create_positions";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        ObjectNode items = props.putObject("items");
        items.put("type", "array").put("description", "岗位数组，最多 20 个").put("maxItems", MAX_ITEMS);
        ObjectNode itemSchema = items.putObject("items");
        itemSchema.put("type", "object");
        ObjectNode ip = itemSchema.putObject("properties");
        ip.putObject("title").put("type", "string").put("description", "岗位名称，必填");
        ip.putObject("companyId").put("type", "integer")
                .put("description", "企业ID，必填；不确定时先用 search_jobs 或企业列表确认");
        ip.putObject("department").put("type", "string").put("description", "部门");
        ip.putObject("city").put("type", "string").put("description", "工作城市");
        ip.putObject("salaryMin").put("type", "integer").put("description", "月薪下限（元）");
        ip.putObject("salaryMax").put("type", "integer").put("description", "月薪上限（元）");
        ip.putObject("experience").put("type", "string").put("description", "经验要求，如 3-5年");
        ip.putObject("education").put("type", "string").put("description", "学历要求，如 本科");
        ip.putObject("description").put("type", "string").put("description", "岗位描述/职责（可选）");
        itemSchema.putArray("required").add("title").add("companyId");
        params.putArray("required").add("items");
        return toolDef("生成待确认的岗位录入草稿（不直接入库，需用户点卡片确认；入库后默认为未上架，需人工上架）。"
                + "用户要求新增或代录岗位时调用；企业ID未知时先确认，不要编造。", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        JsonNode itemsNode = args.path("items");
        if (!itemsNode.isArray() || itemsNode.size() == 0)
        {
            return ToolResult.read("没有可录入的岗位：items 为空。");
        }
        if (itemsNode.size() > MAX_ITEMS)
        {
            return ToolResult.read("一次最多录入 " + MAX_ITEMS + " 个岗位，请分批提交。");
        }

        List<Map<String, Object>> items = new ArrayList<>();
        List<String> invalid = new ArrayList<>();
        List<String> duplicated = new ArrayList<>();
        for (JsonNode node : itemsNode)
        {
            String title = ToolArgs.text(node, "title", 100);
            long companyId = node.path("companyId").asLong(0);
            if (title.isEmpty())
            {
                invalid.add("（岗位名为空）");
                continue;
            }
            if (companyId <= 0)
            {
                invalid.add(title + "（企业ID无效）");
                continue;
            }
            if (!companyExists(companyId))
            {
                invalid.add(title + "（企业ID " + companyId + " 不存在）");
                continue;
            }
            if (exists(companyId, title))
            {
                duplicated.add(title);
                continue;
            }
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("title", title);
            item.put("companyId", companyId);
            item.put("department", ToolArgs.text(node, "department", 50));
            item.put("city", ToolArgs.text(node, "city", 50));
            item.put("salaryMin", intOrNull(node, "salaryMin"));
            item.put("salaryMax", intOrNull(node, "salaryMax"));
            item.put("experience", ToolArgs.text(node, "experience", 50));
            item.put("education", educationCode(ToolArgs.text(node, "education", 20)));
            item.put("description", ToolArgs.text(node, "description", 2000));
            items.add(item);
        }
        if (items.isEmpty())
        {
            List<String> reasons = new ArrayList<>();
            if (!duplicated.isEmpty())
            {
                reasons.add("已存在同企业同岗位：" + String.join("、", duplicated));
            }
            if (!invalid.isEmpty())
            {
                reasons.add("字段不完整：" + String.join("、", invalid));
            }
            return ToolResult.read("未生成岗位草稿。" + String.join("；", reasons));
        }

        PendingAction action = new PendingAction();
        action.put("items", items);
        register(ctx, QuestionBankSupport.SCOPE, "create_positions", "待确认：录入岗位", action);

        StringBuilder out = new StringBuilder();
        out.append("已生成 ").append(items.size()).append(" 个岗位草稿（待确认，尚未入库；入库后为未上架状态）。\n");
        for (int i = 0; i < items.size(); i++)
        {
            Map<String, Object> item = items.get(i);
            out.append(i + 1).append(". ").append(item.get("title"))
                    .append("（企业ID ").append(item.get("companyId")).append("）\n");
        }
        if (!duplicated.isEmpty())
        {
            out.append("已跳过 ").append(duplicated.size()).append(" 个已存在岗位：")
                    .append(String.join("、", duplicated)).append('\n');
        }
        if (!invalid.isEmpty())
        {
            out.append("已跳过 ").append(invalid.size()).append(" 条无效数据：")
                    .append(String.join("、", invalid)).append('\n');
        }
        out.append("pendingId=").append(action.id).append("；请告诉用户点击卡片上的「确认执行」写入。");
        String text = out.toString();
        action.summary = QuestionBankSupport.summarize(text);
        return ToolResult.propose(text, action);
    }

    @Override
    public boolean supports(PendingAction action)
    {
        return "create_positions".equals(action.kind) && QuestionBankSupport.SCOPE.equals(action.scope);
    }

    @Override
    public Map<String, Object> apply(PendingAction action, ToolContext ctx)
    {
        List<Map<String, Object>> items = action.get("items");
        int inserted = 0;
        List<String> skipped = new ArrayList<>();
        List<String> errors = new ArrayList<>();
        Long publisherId = publisherId(ctx);
        if (publisherId == null)
        {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("kind", "create_positions");
            result.put("inserted", 0);
            result.put("skipped", skipped);
            result.put("errors", List.of("未找到当前操作人的系统账号，无法代录岗位"));
            result.put("status", DEFAULT_STATUS);
            return result;
        }
        for (Map<String, Object> item : items)
        {
            String title = String.valueOf(item.get("title"));
            long companyId = ((Number) item.get("companyId")).longValue();
            if (exists(companyId, title))
            {
                skipped.add(title);
                continue;
            }
            try
            {
                String description = item.get("description") == null ? "" : String.valueOf(item.get("description"));
                ObjectNode jd = json.createObjectNode();
                if (!description.isEmpty())
                {
                    jd.put("description", description);
                }
                jdbc.update("INSERT INTO t_pos (pos_company_id, pos_publisher_id, pos_title, pos_department, "
                        + "pos_work_city, pos_salary_min, pos_salary_max, pos_experience_required, "
                        + "pos_education_required, pos_job_type, pos_jd_json, pos_status) "
                        + "VALUES (?,?,?,?,?,?,?,?,?,1,?,?)",
                        companyId, publisherId, title, item.get("department"), item.get("city"),
                        item.get("salaryMin"), item.get("salaryMax"), item.get("experience"),
                        item.get("education"), description.isEmpty() ? null : jd.toString(), DEFAULT_STATUS);
                inserted++;
            }
            catch (Exception e)
            {
                errors.add(title + "：" + e.getMessage());
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("kind", "create_positions");
        result.put("inserted", inserted);
        result.put("skipped", skipped);
        result.put("errors", errors);
        result.put("status", DEFAULT_STATUS);
        return result;
    }

    private Integer intOrNull(JsonNode node, String field)
    {
        JsonNode value = node.path(field);
        return value.isNumber() ? value.asInt() : null;
    }

    /** 学历入库为 tinyint：1-中专 2-大专 3-本科 4-硕士 5-博士。 */
    private Integer educationCode(String text)
    {
        if (text == null || text.isEmpty())
        {
            return null;
        }
        if (text.matches("\\d+"))
        {
            int value = Integer.parseInt(text);
            return value >= 1 && value <= 5 ? value : null;
        }
        if (text.contains("中专"))
        {
            return 1;
        }
        if (text.contains("大专") || text.contains("专科"))
        {
            return 2;
        }
        if (text.contains("本科") || text.contains("学士"))
        {
            return 3;
        }
        if (text.contains("硕士") || text.contains("研究生"))
        {
            return 4;
        }
        if (text.contains("博士"))
        {
            return 5;
        }
        return null;
    }

    private boolean companyExists(long companyId)
    {
        Integer count = jdbc.queryForObject("SELECT COUNT(1) FROM t_cmp WHERE cmp_id=?", Integer.class, companyId);
        return count != null && count > 0;
    }

    private boolean exists(long companyId, String title)
    {
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(1) FROM t_pos WHERE pos_company_id=? AND pos_title=?", Integer.class, companyId, title);
        return count != null && count > 0;
    }

    /** 记录发布人为当前操作的管理员账号，查不到时留空。 */
    private Long publisherId(ToolContext ctx)
    {
        try
        {
            String operator = ctx == null ? null : ctx.getOperator();
            if (operator == null || operator.isBlank())
            {
                return null;
            }
            List<Long> ids = jdbc.queryForList("SELECT user_id FROM sys_user WHERE user_name=?", Long.class, operator);
            return ids.isEmpty() ? null : ids.get(0);
        }
        catch (Exception e)
        {
            return null;
        }
    }
}
