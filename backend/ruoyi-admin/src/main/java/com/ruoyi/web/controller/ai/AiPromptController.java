package com.ruoyi.web.controller.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.system.service.IPromptVersionService;
import com.ruoyi.system.domain.PromptVersion;
import java.util.*;

/**
 * Prompt版本配置（对齐前端 /ai/prompt 接口）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/ai/prompt")
public class AiPromptController extends BaseController {

    @Autowired
    private IPromptVersionService promptVersionService;

    @GetMapping("/list")
    public TableDataInfo list(PromptVersion promptVersion) {
        startPage();
        List<PromptVersion> list = promptVersionService.selectPromptVersionList(promptVersion);
        
        // 字段映射，适配前端期望的字段名
        List<Map<String, Object>> result = new ArrayList<>();
        for (PromptVersion p : list) {
            Map<String, Object> item = new HashMap<>();
            item.put("promptId", p.getPmvId());
            item.put("promptName", p.getPmvName());
            item.put("scene", "interview");
            item.put("interviewType", "tech");
            item.put("version", p.getPmvVersion());
            item.put("content", p.getPmvContent());
            item.put("status", p.getPmvStatus());
            item.put("lastModifiedBy", "admin");
            result.add(item);
        }
        
        return getDataTable(result);
    }

    @GetMapping("/{promptId}")
    public AjaxResult getInfo(@PathVariable Long promptId) {
        return success(promptVersionService.selectPromptVersionByPmvId(promptId));
    }

    @PostMapping
    public AjaxResult add(@RequestBody PromptVersion promptVersion) {
        return toAjax(promptVersionService.insertPromptVersion(promptVersion));
    }

    @PutMapping
    public AjaxResult edit(@RequestBody PromptVersion promptVersion) {
        return toAjax(promptVersionService.updatePromptVersion(promptVersion));
    }

    @DeleteMapping("/{promptIds}")
    public AjaxResult remove(@PathVariable Long[] promptIds) {
        for (Long id : promptIds) {
            promptVersionService.deletePromptVersionByPmvId(id);
        }
        return success();
    }
}
