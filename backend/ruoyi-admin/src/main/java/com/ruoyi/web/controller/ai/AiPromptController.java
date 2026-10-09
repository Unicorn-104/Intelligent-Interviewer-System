package com.ruoyi.web.controller.ai;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
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

    @PreAuthorize("@ss.hasPermi('ai:prompt:list')")
    @GetMapping("/list")
    public TableDataInfo list(PromptVersion promptVersion) {
        startPage();
        List<PromptVersion> list = promptVersionService.selectPromptVersionList(promptVersion);

        List<Map<String, Object>> result = new ArrayList<>();
        for (PromptVersion p : list) {
            Map<String, Object> item = new HashMap<>();
            item.put("promptId", p.getPmvId());
            item.put("promptName", p.getPmvName());
            item.put("version", p.getPmvVersion());
            item.put("content", p.getPmvContent());
            item.put("status", p.getPmvStatus());
            result.add(item);
        }

        return getDataTable(result);
    }

    @PreAuthorize("@ss.hasPermi('ai:prompt:query')")
    @GetMapping("/{promptId}")
    public AjaxResult getInfo(@PathVariable Long promptId) {
        return success(promptVersionService.selectPromptVersionByPmvId(promptId));
    }

    @PreAuthorize("@ss.hasPermi('ai:prompt:add')")
    @PostMapping
    public AjaxResult add(@RequestBody PromptVersion promptVersion) {
        return toAjax(promptVersionService.insertPromptVersion(promptVersion));
    }

    @PreAuthorize("@ss.hasPermi('ai:prompt:edit')")
    @PutMapping
    public AjaxResult edit(@RequestBody PromptVersion promptVersion) {
        return toAjax(promptVersionService.updatePromptVersion(promptVersion));
    }

    @PreAuthorize("@ss.hasPermi('ai:prompt:remove')")
    @Transactional(rollbackFor = Exception.class)
    @DeleteMapping("/{promptIds}")
    public AjaxResult remove(@PathVariable Long[] promptIds) {
        for (Long id : promptIds) {
            promptVersionService.deletePromptVersionByPmvId(id);
        }
        return success();
    }

    /**
     * 发布Prompt
     */
    @PreAuthorize("@ss.hasPermi('ai:prompt:publish')")
    @PutMapping("/publish")
    public AjaxResult publish(@RequestBody Map<String, Object> data) {
        Object promptIdObj = data.get("promptId");
        if (promptIdObj == null) {
            return AjaxResult.error("Prompt ID不能为空");
        }
        Long promptId = ((Number) promptIdObj).longValue();
        PromptVersion pv = new PromptVersion();
        pv.setPmvId(promptId);
        pv.setPmvStatus(1);
        return toAjax(promptVersionService.updatePromptVersion(pv));
    }

    /**
     * 查询Prompt版本历史
     */
    @PreAuthorize("@ss.hasPermi('ai:prompt:list')")
    @GetMapping("/versions/{promptId}")
    public AjaxResult listVersions(@PathVariable("promptId") Long promptId) {
        PromptVersion pv = promptVersionService.selectPromptVersionByPmvId(promptId);
        List<Map<String, Object>> result = new ArrayList<>();
        if (pv != null) {
            Map<String, Object> item = new HashMap<>();
            item.put("version", pv.getPmvVersion());
            item.put("content", pv.getPmvContent());
            item.put("status", pv.getPmvStatus());
            item.put("createdAt", pv.getPmvCreatedAt());
            result.add(item);
        }
        return success(result);
    }
}
