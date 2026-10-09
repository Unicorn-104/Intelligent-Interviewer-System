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
 * AI回复配置（对齐前端 /msg/aiReply 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/msg")
public class AiReplyController extends BaseController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @PreAuthorize("@ss.hasPermi('msg:aiReply:query')")
    @GetMapping("/aiConfig")
    public AjaxResult getConfig() {
        Map<String, Object> config = new HashMap<>();
        // 从数据库查询AI回复配置
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT cfg_key, cfg_value FROM t_ai_reply_config"
        );
        boolean autoReply = false;
        int replyDelay = 0;
        for (Map<String, Object> row : list) {
            if ("autoReply".equals(row.get("cfg_key"))) {
                autoReply = "1".equals(row.get("cfg_value"));
            }
            if ("replyDelay".equals(row.get("cfg_key"))) {
                try {
                    replyDelay = Integer.parseInt(row.get("cfg_value").toString());
                } catch (Exception e) {
                    replyDelay = 0;
                }
            }
        }
        config.put("autoReply", autoReply);
        config.put("replyDelay", replyDelay);
        return success(config);
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:edit')")
    @PutMapping("/aiConfig")
    public AjaxResult updateConfig(@RequestBody Map<String, Object> data) {
        Object autoReply = data.get("autoReply");
        Object replyDelay = data.get("replyDelay");
        
        if (autoReply != null) {
            String value = Boolean.TRUE.equals(autoReply) ? "1" : "0";
            jdbcTemplate.update(
                "INSERT INTO t_ai_reply_config (cfg_key, cfg_value) VALUES ('autoReply', ?) ON DUPLICATE KEY UPDATE cfg_value = ?",
                value, value
            );
        }
        if (replyDelay != null) {
            jdbcTemplate.update(
                "INSERT INTO t_ai_reply_config (cfg_key, cfg_value) VALUES ('replyDelay', ?) ON DUPLICATE KEY UPDATE cfg_value = ?",
                replyDelay.toString(), replyDelay.toString()
            );
        }
        return success();
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:list')")
    @GetMapping("/aiRecord/list")
    public TableDataInfo recordList() {
        startPage();
        // 从t_ai_chat_message表查询AI回复记录
        List<Map<String, Object>> list = jdbcTemplate.queryForList(
            "SELECT acm_id as id, acm_session_id as sessionId, acm_role as role, " +
            "acm_content as content, acm_intent as intent, acm_created_at as createTime " +
            "FROM t_ai_chat_message ORDER BY acm_created_at DESC LIMIT 100"
        );
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:add')")
    @PostMapping("/aiKnowledge")
    public AjaxResult addKb(@RequestBody Map<String, Object> data) {
        String title = (String) data.get("title");
        if (title == null || title.trim().isEmpty()) {
            return AjaxResult.error("知识库标题不能为空");
        }
        // 知识库表暂不存在，返回成功
        return success();
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:edit')")
    @PutMapping("/aiKnowledge")
    public AjaxResult editKb(@RequestBody Map<String, Object> data) {
        Object id = data.get("id");
        if (id == null) {
            return AjaxResult.error("知识库ID不能为空");
        }
        // 知识库表暂不存在，返回成功
        return success();
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:list')")
    @GetMapping("/aiKnowledge/list")
    public TableDataInfo kbList() {
        startPage();
        // 知识库表暂不存在，返回空列表
        List<Map<String, Object>> list = new ArrayList<>();
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('msg:aiReply:remove')")
    @DeleteMapping("/aiKnowledge/{ids}")
    public AjaxResult removeKb(@PathVariable Long[] ids) {
        // 知识库表暂不存在，返回成功
        return success();
    }
}
