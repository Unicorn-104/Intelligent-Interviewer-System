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
 * AI回复配置、应答记录与知识库（对齐前端 /msg/aiReply）
 */
@RestController
@RequestMapping("/msg")
public class AiReplyController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /** 读取单个配置项，缺省返回 defaultVal */
    private String getCfg(String key, String defaultVal) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT cfg_value FROM t_ai_reply_config WHERE cfg_key = ?", key);
        if (rows.isEmpty() || rows.get(0).get("cfg_value") == null) return defaultVal;
        return rows.get(0).get("cfg_value").toString();
    }

    private void upsertCfg(String key, String value) {
        jdbcTemplate.update(
            "INSERT INTO t_ai_reply_config (cfg_key, cfg_value) VALUES (?, ?) " +
            "ON DUPLICATE KEY UPDATE cfg_value = VALUES(cfg_value)", key, value);
    }

    /** AI应答配置 */
    @PreAuthorize("@ss.hasPermi('msg:aiReply:query')")
    @GetMapping("/aiConfig")
    public AjaxResult getConfig() {
        Map<String, Object> config = new HashMap<>();
        config.put("enabled", "1".equals(getCfg("enabled", "0")));
        config.put("language", getCfg("language", "zh"));
        config.put("style", getCfg("style", "formal"));
        config.put("timeout", Integer.parseInt(getCfg("timeout", "10")));
        config.put("autoReply", getCfg("autoReply", "simple"));
        config.put("knowledgeBaseId", getCfg("knowledgeBaseId", ""));
        return success(config);
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:edit')")
    @PutMapping("/aiConfig")
    public AjaxResult updateConfig(@RequestBody Map<String, Object> data) {
        if (data.containsKey("enabled")) {
            upsertCfg("enabled", Boolean.TRUE.equals(data.get("enabled")) ? "1" : "0");
        }
        if (data.get("language") != null) upsertCfg("language", data.get("language").toString());
        if (data.get("style") != null) upsertCfg("style", data.get("style").toString());
        if (data.get("timeout") != null) upsertCfg("timeout", data.get("timeout").toString());
        if (data.get("autoReply") != null) upsertCfg("autoReply", data.get("autoReply").toString());
        return success();
    }

    /** 最近应答记录：流式返回聊天消息，user 内容作 question、assistant 内容作 answer */
    @PreAuthorize("@ss.hasPermi('msg:aiReply:list')")
    @GetMapping("/aiRecord/list")
    public TableDataInfo recordList() {
        startPage();
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT acm_id AS id, acm_role AS role, acm_content AS content, " +
            "acm_intent AS intent, acm_user_id AS userId, acm_transfer_to_human AS transferHuman, " +
            "acm_response_time AS responseTime, acm_created_at AS createTime, " +
            "u.nick_name AS userName " +
            "FROM t_ai_chat_message m LEFT JOIN sys_user u ON m.acm_user_id = u.user_id " +
            "ORDER BY acm_created_at DESC LIMIT 100");
        List<Map<String, Object>> result = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Map<String, Object> item = new HashMap<>();
            int role = row.get("role") == null ? 0 : ((Number) row.get("role")).intValue();
            item.put("question", role == 1 ? row.get("content") : "");
            item.put("answer", role == 2 ? row.get("content") : "");
            item.put("intent", row.get("intent"));
            item.put("userName", row.get("userName"));
            item.put("transferToHuman", row.get("transferHuman") != null && ((Number) row.get("transferHuman")).intValue() == 1 ? "1" : "0");
            item.put("responseTime", row.get("responseTime"));
            item.put("createTime", row.get("createTime"));
            result.add(item);
        }
        return getDataTable(result);
    }

    /** 知识库列表：支持关键词（问题/回答）与分类筛选 */
    @PreAuthorize("@ss.hasPermi('msg:aiReply:list')")
    @GetMapping("/aiKnowledge/list")
    public TableDataInfo kbList(@RequestParam(required = false) String keyword,
                                @RequestParam(required = false) String category) {
        startPage();
        StringBuilder sql = new StringBuilder(
            "SELECT kb_id AS id, question, answer, category, use_count AS useCount, " +
            "created_at AS createTime FROM t_ai_knowledge WHERE 1=1 ");
        List<Object> args = new ArrayList<>();
        if (keyword != null && !keyword.trim().isEmpty()) {
            sql.append("AND (question LIKE ? OR answer LIKE ?) ");
            args.add("%" + keyword.trim() + "%");
            args.add("%" + keyword.trim() + "%");
        }
        if (category != null && !category.trim().isEmpty()) {
            sql.append("AND category = ? ");
            args.add(category);
        }
        sql.append("ORDER BY kb_id DESC");
        List<Map<String, Object>> list = jdbcTemplate.queryForList(sql.toString(), args.toArray());
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:add')")
    @PostMapping("/aiKnowledge")
    public AjaxResult addKb(@RequestBody Map<String, Object> data) {
        String question = (String) data.get("question");
        String answer = (String) data.get("answer");
        if (question == null || question.trim().isEmpty()) return AjaxResult.error("问题不能为空");
        if (answer == null || answer.trim().isEmpty()) return AjaxResult.error("回答不能为空");
        jdbcTemplate.update(
            "INSERT INTO t_ai_knowledge (question, answer, category) VALUES (?, ?, ?)",
            question.trim(), answer.trim(), data.get("category"));
        return success();
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:edit')")
    @PutMapping("/aiKnowledge")
    public AjaxResult editKb(@RequestBody Map<String, Object> data) {
        Object id = data.get("id");
        if (id == null) return AjaxResult.error("知识库ID不能为空");
        jdbcTemplate.update(
            "UPDATE t_ai_knowledge SET question = ?, answer = ?, category = ? WHERE kb_id = ?",
            data.get("question"), data.get("answer"), data.get("category"), id);
        return success();
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:remove')")
    @DeleteMapping("/aiKnowledge/{ids}")
    public AjaxResult removeKb(@PathVariable Long[] ids) {
        for (Long id : ids) {
            jdbcTemplate.update("DELETE FROM t_ai_knowledge WHERE kb_id = ?", id);
        }
        return success();
    }
}
