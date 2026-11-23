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
import com.ruoyi.ai.core.ToolArgs;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

/** 查询最近的题库导入记录，用于定位需要撤销的批次号。 */
@Component
public class ListImportBatchesTool extends AbstractAgentTool
{
    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "list_import_batches";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        params.putObject("properties").putObject("pageSize").put("type", "integer")
                .put("minimum", 1).put("maximum", 20);
        return toolDef("查询最近的题库导入记录（可用于找需要撤销的批次号）", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        int size = Math.min(Math.max(ToolArgs.intValue(args, "pageSize", 10), 1), QuestionBankSupport.MAX_BATCHES);
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT eqb_id AS id, eqb_type AS type, eqb_file_name AS fileName, eqb_total AS total, "
                + "eqb_inserted AS inserted, eqb_status AS status, eqb_operator AS operator, "
                + "eqb_created_at AS createTime FROM t_exam_question_import_batch ORDER BY eqb_id DESC LIMIT ?", size);
        if (rows.isEmpty())
        {
            return ToolResult.read("没有导入记录。");
        }
        StringBuilder out = new StringBuilder("最近 " + rows.size() + " 条导入记录：\n");
        for (Map<String, Object> row : rows)
        {
            int type = ((Number) row.get("type")).intValue();
            int status = ((Number) row.get("status")).intValue();
            out.append("- 批次#").append(row.get("id"))
               .append(' ').append(type == 1 ? "文件导入" : "单条新增")
               .append(row.get("fileName") == null ? "" : "「" + row.get("fileName") + "」")
               .append(' ').append(row.get("inserted")).append('/').append(row.get("total"))
               .append(' ').append(status == 0 ? "正常" : "已撤销")
               .append(' ').append(row.get("createTime")).append("\n");
        }
        return ToolResult.read(out.toString());
    }
}
