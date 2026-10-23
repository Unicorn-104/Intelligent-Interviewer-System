package com.ruoyi.web.controller.msg;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;

import java.util.*;

/**
 * 消息模板管理Controller
 */
@RestController
@RequestMapping("/msg/template")
public class MsgTemplateController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /** 渠道字符串 -> 库内 tinyint：site/system=1 站内，email=2 邮件，sms=3 短信 */
    private Integer channelToDb(String channel) {
        if (channel == null) return 1;
        switch (channel) {
            case "email": return 2;
            case "sms": return 3;
            default: return 1;
        }
    }

    /** 库内 tinyint -> 前端渠道字符串 */
    private String dbToChannel(Object db) {
        if (db == null) return "site";
        int v = ((Number) db).intValue();
        if (v == 2) return "email";
        if (v == 3) return "sms";
        return "site";
    }

    private List<String> splitVariables(String raw) {
        if (raw == null || raw.trim().isEmpty()) return new ArrayList<>();
        String[] parts = raw.split(",");
        List<String> list = new ArrayList<>();
        for (String p : parts) {
            if (!p.trim().isEmpty()) list.add(p.trim());
        }
        return list;
    }

    /** 列表：支持模板名称、渠道、消息类型、状态筛选 */
    @PreAuthorize("@ss.hasPermi('msg:template:list')")
    @GetMapping("/list")
    public TableDataInfo list(
            @RequestParam(required = false) String templateName,
            @RequestParam(required = false) String channel,
            @RequestParam(required = false) String msgType,
            @RequestParam(required = false) String status) {
        startPage();
        StringBuilder sql = new StringBuilder(
            "SELECT tpl_id AS templateId, tpl_code AS templateCode, tpl_title AS templateName, " +
            "tpl_content AS content, tpl_channel AS channelDb, tpl_msg_type AS msgType, " +
            "tpl_variables AS variables, tpl_status AS status, tpl_updated_at AS updateTime " +
            "FROM t_msg_template WHERE 1=1 ");
        List<Object> args = new ArrayList<>();
        if (templateName != null && !templateName.trim().isEmpty()) {
            sql.append("AND tpl_title LIKE ? ");
            args.add("%" + templateName.trim() + "%");
        }
        if (channel != null && !channel.trim().isEmpty()) {
            sql.append("AND tpl_channel = ? ");
            args.add(channelToDb(channel));
        }
        if (msgType != null && !msgType.trim().isEmpty()) {
            sql.append("AND tpl_msg_type = ? ");
            args.add(msgType);
        }
        if (status != null && !status.trim().isEmpty()) {
            sql.append("AND tpl_status = ? ");
            args.add(status);
        }
        sql.append("ORDER BY tpl_updated_at DESC");

        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql.toString(), args.toArray());
        for (Map<String, Object> row : rows) {
            row.put("channel", dbToChannel(row.remove("channelDb")));
            row.put("variables", splitVariables((String) row.get("variables")));
        }
        return getDataTable(rows);
    }

    /** 详情 */
    @PreAuthorize("@ss.hasPermi('msg:template:list')")
    @GetMapping("/{id}")
    public AjaxResult getById(@PathVariable Long id) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT tpl_id AS templateId, tpl_code AS templateCode, tpl_title AS templateName, " +
            "tpl_content AS content, tpl_channel AS channelDb, tpl_msg_type AS msgType, " +
            "tpl_variables AS variables, tpl_status AS status, tpl_updated_at AS updateTime " +
            "FROM t_msg_template WHERE tpl_id = ?", id);
        if (rows.isEmpty()) {
            return AjaxResult.error("模板不存在");
        }
        Map<String, Object> row = rows.get(0);
        row.put("channel", dbToChannel(row.remove("channelDb")));
        row.put("variables", splitVariables((String) row.get("variables")));
        return success(row);
    }

    @PreAuthorize("@ss.hasPermi('msg:template:add')")
    @PostMapping
    public AjaxResult add(@RequestBody Map<String, Object> body) {
        String code = (String) body.get("templateCode");
        String title = (String) body.get("templateName");
        String content = (String) body.get("content");
        if (code == null || code.trim().isEmpty()) return AjaxResult.error("模板编码不能为空");
        if (title == null || title.trim().isEmpty()) return AjaxResult.error("模板名称不能为空");
        if (content == null || content.trim().isEmpty()) return AjaxResult.error("模板内容不能为空");
        Integer exists = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM t_msg_template WHERE tpl_code = ?", Integer.class, code.trim());
        if (exists != null && exists > 0) return AjaxResult.error("模板编码已存在");

        String variables = joinVariables(body.get("variables"));
        jdbcTemplate.update(
            "INSERT INTO t_msg_template (tpl_code, tpl_title, tpl_content, tpl_channel, tpl_msg_type, tpl_variables, tpl_status) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            code.trim(), title.trim(), content, channelToDb((String) body.get("channel")),
            body.get("msgType"), variables, body.get("status") == null ? "1" : body.get("status").toString());
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('msg:template:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody Map<String, Object> body) {
        Object id = body.get("templateId");
        if (id == null) return AjaxResult.error("模板ID不能为空");
        String title = (String) body.get("templateName");
        String content = (String) body.get("content");
        String variables = joinVariables(body.get("variables"));
        jdbcTemplate.update(
            "UPDATE t_msg_template SET tpl_title = ?, tpl_content = ?, tpl_channel = ?, " +
            "tpl_msg_type = ?, tpl_variables = ?, tpl_status = ?, tpl_updated_at = NOW() WHERE tpl_id = ?",
            title, content, channelToDb((String) body.get("channel")),
            body.get("msgType"), variables,
            body.get("status") == null ? "1" : body.get("status").toString(), id);
        return AjaxResult.success();
    }

    @PreAuthorize("@ss.hasPermi('msg:template:remove')")
    @DeleteMapping("/{ids}")
    public AjaxResult remove(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_msg_template WHERE tpl_id = ?", id);
        }
        return AjaxResult.success();
    }

    @SuppressWarnings("unchecked")
    private String joinVariables(Object variables) {
        if (variables == null) return null;
        if (variables instanceof List) {
            List<String> list = (List<String>) variables;
            return String.join(",", list);
        }
        return variables.toString();
    }
}
