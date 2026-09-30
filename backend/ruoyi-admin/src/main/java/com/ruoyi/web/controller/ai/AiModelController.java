package com.ruoyi.web.controller.ai;

import org.springframework.beans.factory.annotation.Autowired;
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
            item.put("provider", "openai");
            item.put("modelTypes", List.of("chat"));
            item.put("apiUrl", m.getMppApiUrl());
            item.put("apiKey", m.getMppApiKey());
            item.put("unitPrice", 0.01);
            item.put("status", m.getMppStatus());
            result.add(item);
        }
        
        return getDataTable(result);
    }

    @GetMapping("/{modelId}")
    public AjaxResult getInfo(@PathVariable Long modelId) {
        return success(modelProviderService.selectModelProviderByMppId(modelId));
    }

    @PostMapping
    public AjaxResult add(@RequestBody ModelProvider modelProvider) {
        return toAjax(modelProviderService.insertModelProvider(modelProvider));
    }

    @PutMapping
    public AjaxResult edit(@RequestBody ModelProvider modelProvider) {
        return toAjax(modelProviderService.updateModelProvider(modelProvider));
    }

    @DeleteMapping("/{modelIds}")
    public AjaxResult remove(@PathVariable Long[] modelIds) {
        for (Long id : modelIds) {
            modelProviderService.deleteModelProviderByMppId(id);
        }
        return success();
    }

    @PutMapping("/changeStatus")
    public AjaxResult changeStatus(@RequestBody Map<String, Object> data) {
        return success();
    }

    @PostMapping("/test")
    public AjaxResult test(@RequestBody Map<String, Object> data) {
        return success("连接成功");
    }
}
