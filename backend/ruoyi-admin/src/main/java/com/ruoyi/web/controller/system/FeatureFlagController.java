package com.ruoyi.web.controller.system;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.SysConfig;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 功能开关管理
 */
@RestController
@RequestMapping("/system/feature")
public class FeatureFlagController extends BaseController {

    @Autowired
    private ISysConfigService configService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    /** 所有功能开关定义：key -> [端分组, 名称, 描述, 图标, 颜色] */
    private static final Map<String, Object[]> FEATURES = new LinkedHashMap<>();
    static {
        // 求职者端App：只开关增值功能，核心功能(岗位/简历/投递/面试/消息)不做开关
        FEATURES.put("capp.ai",       new Object[]{"求职者端App", "AI求职助手", "AI岗位推荐、智能问答", "MagicStick", "#8b5cf6"});
        FEATURES.put("capp.companies", new Object[]{"求职者端App", "企业浏览", "企业主页、公司列表、企业收藏", "OfficeBuilding", "#06b6d4"});
        FEATURES.put("capp.support",   new Object[]{"求职者端App", "帮助客服", "帮助中心、常见问题、在线客服", "Service", "#64748b"});
        // 求职者PC端：只开关增值功能
        FEATURES.put("uap.ai",         new Object[]{"求职者PC端", "AI求职助手", "AI岗位推荐、智能问答助手", "MagicStick", "#8b5cf6"});
        FEATURES.put("uap.mock",       new Object[]{"求职者PC端", "模拟面试", "AI模拟面试练习、面试题演练", "VideoCamera", "#ec4899"});
        FEATURES.put("uap.exam",       new Object[]{"求职者PC端", "在线笔试", "在线考试答题、考试监控", "School", "#8b5cf6"});
        FEATURES.put("uap.companies",  new Object[]{"求职者PC端", "企业主页", "企业详情页、企业介绍展示", "OfficeBuilding", "#06b6d4"});
        // 企业端App：只开关增值功能，核心功能(岗位/面试/审核/Offer)不做开关
        FEATURES.put("eapp.assistant",  new Object[]{"企业端App", "AI招聘助手", "AI对话辅助、简历解读、面试建议", "MagicStick", "#8b5cf6"});
        FEATURES.put("eapp.schedule",   new Object[]{"企业端App", "面试预约调度", "候选人自助预约、日历协调", "Calendar", "#ec4899"});
        FEATURES.put("eapp.screening",  new Object[]{"企业端App", "AI简历评分", "简历自动打分、匹配度排序、初筛报告", "Tools", "#6366f1"});
        FEATURES.put("eapp.talent",     new Object[]{"企业端App", "人才库", "历史候选人资源池、人才搜索", "Star", "#f97316"});
        // 企业端Web：只开关增值功能
        FEATURES.put("epc.screening",  new Object[]{"企业端Web", "AI简历评分", "批量打分、匹配度排序、初筛流水线", "Tools", "#6366f1"});
        FEATURES.put("epc.talent",     new Object[]{"企业端Web", "人才库", "人才资源池、标签管理", "Star", "#f97316"});
        FEATURES.put("epc.survey",     new Object[]{"企业端Web", "满意度调研", "面试后问卷、候选人反馈收集", "Document", "#06b6d4"});
        FEATURES.put("epc.exam",       new Object[]{"企业端Web", "在线笔试", "在线考试、监考监控、自动判分", "School", "#8b5cf6"});
    }

    @GetMapping("/list")
    public AjaxResult list() {
        List<Map<String, Object>> list = new ArrayList<>();
        for (Map.Entry<String, Object[]> e : FEATURES.entrySet()) {
            String key = e.getKey();
            Object[] info = e.getValue();
            String value = configService.selectConfigByKey("feature." + key);
            boolean enabled = value == null || value.isEmpty() ? true : "true".equals(value);
            Map<String, Object> item = new HashMap<>();
            item.put("key", key);
            item.put("group", info[0]);
            item.put("name", info[1]);
            item.put("desc", info[2]);
            item.put("icon", info[3]);
            item.put("color", info[4]);
            item.put("enabled", enabled);
            list.add(item);
        }
        return AjaxResult.success(list);
    }

    @PostMapping("/save")
    public AjaxResult save(@RequestBody Map<String, Boolean> body) {
        for (Map.Entry<String, Boolean> e : body.entrySet()) {
            String configKey = "feature." + e.getKey();
            String configValue = e.getValue() ? "true" : "false";
            // 查询是否已存在
            SysConfig existing = configService.selectConfigByKey(configKey) != null && !configService.selectConfigByKey(configKey).isEmpty()
                ? new SysConfig() : null;
            // 用selectConfigList判断key是否存在
            SysConfig query = new SysConfig();
            query.setConfigKey(configKey);
            List<SysConfig> existList = configService.selectConfigList(query);
            if (existList != null && !existList.isEmpty()) {
                SysConfig update = existList.get(0);
                update.setConfigValue(configValue);
                configService.updateConfig(update);
            } else {
                SysConfig insert = new SysConfig();
                insert.setConfigName("功能开关-" + e.getKey());
                insert.setConfigKey(configKey);
                insert.setConfigValue(configValue);
                insert.setConfigType("Y");
                insert.setCreateBy("admin");
                configService.insertConfig(insert);
            }
        }
        configService.resetConfigCache();
        return AjaxResult.success();
    }

    /** 查询某功能的企业覆盖列表（返回所有企业+覆盖状态） */
    @GetMapping("/overrides/{key}")
    public AjaxResult overrides(@PathVariable String key) {
        // 查所有企业
        List<Map<String, Object>> enterprises = jdbcTemplate.queryForList(
            "SELECT ent_id as id, ent_name as name, ent_contact as contact FROM t_enterprise ORDER BY ent_id LIMIT 200");
        // 查已有的覆盖
        List<Map<String, Object>> existing = jdbcTemplate.queryForList(
            "SELECT enterprise_id, enabled FROM feature_flag_override WHERE feature_key = ?", key);
        Map<Long, Boolean> overrideMap = new HashMap<>();
        for (Map<String, Object> row : existing) {
            Long eid = ((Number) row.get("enterprise_id")).longValue();
            overrideMap.put(eid, ((Number) row.get("enabled")).intValue() == 1);
        }
        // 合并
        for (Map<String, Object> ent : enterprises) {
            Long eid = ((Number) ent.get("id")).longValue();
            ent.put("override", overrideMap.containsKey(eid));
            ent.put("enabled", overrideMap.getOrDefault(eid, true));
        }
        Map<String, Object> result = new HashMap<>();
        result.put("featureKey", key);
        result.put("enterprises", enterprises);
        return AjaxResult.success(result);
    }

    /** 保存企业覆盖 */
    @PostMapping("/overrides/save")
    public AjaxResult saveOverrides(@RequestBody Map<String, Object> body) {
        String key = (String) body.get("featureKey");
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> list = (List<Map<String, Object>>) body.get("overrides");
        // 先删旧的
        jdbcTemplate.update("DELETE FROM feature_flag_override WHERE feature_key = ?", key);
        // 再插新的（只保存有覆盖的）
        for (Map<String, Object> item : list) {
            Boolean override = (Boolean) item.get("override");
            if (override != null && override) {
                Long enterpriseId = ((Number) item.get("id")).longValue();
                Boolean enabled = (Boolean) item.get("enabled");
                jdbcTemplate.update(
                    "INSERT INTO feature_flag_override (enterprise_id, feature_key, enabled, create_by) VALUES (?, ?, ?, 'admin')",
                    enterpriseId, key, enabled != null && enabled ? 1 : 0);
            }
        }
        return AjaxResult.success();
    }
}
