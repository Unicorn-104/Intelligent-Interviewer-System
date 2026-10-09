package com.ruoyi.web.controller.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.service.IModelProviderService;
import com.ruoyi.system.domain.ModelProvider;
import java.util.*;

/**
 * AI模型配置（对齐前端 /ai/model 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/model")
public class AiModelController extends BaseController {

    @Autowired
    private IModelProviderService modelProviderService;

    @PreAuthorize("@ss.hasPermi('ai:model:list')")
    @GetMapping("/list")
    public TableDataInfo list(ModelProvider modelProvider) {
        startPage();
        List<ModelProvider> list = modelProviderService.selectModelProviderList(modelProvider);
        
        // 字段映射，适配前端期望的字段名
        List<Map<String, Object>> result = new ArrayList<>();
        for (ModelProvider m : list) {
            Map<String, Object> item = new HashMap<>();
            item.put("modelId", m.getMppId());
            item.put("modelName", m.getMppName());
            // 从apiUrl推断provider
            String apiUrl = m.getMppApiUrl() != null ? m.getMppApiUrl() : "";
            String provider;
            if (apiUrl.contains("openai")) provider = "openai";
            else if (apiUrl.contains("baidu") || apiUrl.contains("wenxin")) provider = "baidu";
            else if (apiUrl.contains("anthropic") || apiUrl.contains("claude")) provider = "anthropic";
            else if (apiUrl.contains("google") || apiUrl.contains("gemini")) provider = "google";
            else provider = "custom";
            item.put("provider", provider);
            // 从params_json解析modelTypes
            List<String> modelTypes = new ArrayList<>();
            modelTypes.add("chat");
            item.put("modelTypes", modelTypes);
            item.put("apiUrl", m.getMppApiUrl());
            // apiKey脱敏：只显示前4位和后4位
            String apiKey = m.getMppApiKey();
            if (apiKey != null && apiKey.length() > 8) {
                item.put("apiKey", apiKey.substring(0, 4) + "****" + apiKey.substring(apiKey.length() - 4));
            } else {
                item.put("apiKey", apiKey);
            }
            item.put("unitPrice", 0.01);
            item.put("status", m.getMppStatus());
            result.add(item);
        }
        
        return getDataTable(result);
    }

    @PreAuthorize("@ss.hasPermi('ai:model:query')")
    @GetMapping("/{modelId}")
    public AjaxResult getInfo(@PathVariable Long modelId) {
        ModelProvider m = modelProviderService.selectModelProviderByMppId(modelId);
        if (m == null) {
            return error("模型不存在");
        }
        Map<String, Object> result = new HashMap<>();
        result.put("modelId", m.getMppId());
        result.put("modelName", m.getMppName());
        result.put("apiUrl", m.getMppApiUrl());
        result.put("status", m.getMppStatus());
        return success(result);
    }

    @PreAuthorize("@ss.hasPermi('ai:model:add')")
    @PostMapping
    public AjaxResult add(@RequestBody ModelProvider modelProvider) {
        return toAjax(modelProviderService.insertModelProvider(modelProvider));
    }

    @PreAuthorize("@ss.hasPermi('ai:model:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody ModelProvider modelProvider) {
        return toAjax(modelProviderService.updateModelProvider(modelProvider));
    }

    @PreAuthorize("@ss.hasPermi('ai:model:remove')")
    @Transactional(rollbackFor = Exception.class)
    @DeleteMapping("/{modelIds}")
    public AjaxResult remove(@PathVariable Long[] modelIds) {
        for (Long id : modelIds) {
            modelProviderService.deleteModelProviderByMppId(id);
        }
        return success();
    }

    @PreAuthorize("@ss.hasPermi('ai:model:edit')")
    @PutMapping("/changeStatus")
    public AjaxResult changeStatus(@RequestBody Map<String, Object> data) {
        Object modelIdObj = data.get("modelId");
        if (modelIdObj == null) {
            return AjaxResult.error("模型ID不能为空");
        }
        Object statusObj = data.get("status");
        if (statusObj == null) {
            return AjaxResult.error("状态不能为空");
        }
        ModelProvider model = new ModelProvider();
        model.setMppId(((Number) modelIdObj).longValue());
        model.setMppStatus(Integer.valueOf(statusObj.toString()));
        return toAjax(modelProviderService.updateModelProvider(model));
    }

    @PreAuthorize("@ss.hasPermi('ai:model:edit')")
    @PostMapping("/test")
    public AjaxResult test(@RequestBody Map<String, Object> data) {
        String apiUrl = (String) data.get("apiUrl");
        if (apiUrl == null || apiUrl.isEmpty()) {
            return error("API地址不能为空");
        }
        // SSRF防护：只允许http/https，禁止内网地址
        if (!apiUrl.startsWith("http://") && !apiUrl.startsWith("https://")) {
            return error("只允许http/https协议");
        }
        // 禁止内网地址和本地地址
        if (apiUrl.contains("127.0.0.1") || apiUrl.contains("localhost") || 
            apiUrl.contains("169.254.") || apiUrl.contains("10.") || 
            apiUrl.contains("172.16.") || apiUrl.contains("172.17.") || 
            apiUrl.contains("172.18.") || apiUrl.contains("172.19.") ||
            apiUrl.contains("172.20.") || apiUrl.contains("172.21.") ||
            apiUrl.contains("172.22.") || apiUrl.contains("172.23.") ||
            apiUrl.contains("172.24.") || apiUrl.contains("172.25.") ||
            apiUrl.contains("172.26.") || apiUrl.contains("172.27.") ||
            apiUrl.contains("172.28.") || apiUrl.contains("172.29.") ||
            apiUrl.contains("172.30.") || apiUrl.contains("172.31.") ||
            apiUrl.contains("192.168.")) {
            return error("禁止访问内网地址");
        }
        try {
            java.net.HttpURLConnection conn = (java.net.HttpURLConnection) new java.net.URL(apiUrl).openConnection();
            conn.setConnectTimeout(3000);
            conn.setReadTimeout(3000);
            int code = conn.getResponseCode();
            conn.disconnect();
            return success("连接成功，HTTP状态码：" + code);
        } catch (Exception e) {
            return error("连接失败：" + e.getMessage());
        }
    }
}
