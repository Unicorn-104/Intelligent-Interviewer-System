package com.ruoyi.web.controller.app;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.app.ai.AppAiMemoryService;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/app/ai")
public class AppAiMemoryController extends BaseController
{
    private final AppAiMemoryService service;
    public AppAiMemoryController(AppAiMemoryService service) { this.service = service; }

    @GetMapping("/memory-settings")
    public AjaxResult settings() { return success(service.settings(getUserId())); }

    public record MemorySettings(Boolean enabled, Long revision) { }

    @PutMapping("/memory-settings")
    public AjaxResult settings(@RequestBody MemorySettings request)
    {
        return success(service.change(getUserId(), new AppAiMemoryService.Change("settings", null, null,
                request == null ? null : request.enabled(), request == null ? null : request.revision())));
    }

    @GetMapping("/memories")
    public AjaxResult read() { return success(service.read(getUserId())); }

    @GetMapping("/long-term-memories")
    public AjaxResult longTermMemories() { return success(service.longTermMemories(getUserId())); }

    @PutMapping("/long-term-memories/{id}")
    public AjaxResult updateLongTermMemory(@PathVariable String id,
            @RequestBody com.ruoyi.system.service.app.ai.AppAiLongTermMemoryService.UpdateRequest request)
    { return success(service.updateLongTermMemory(getUserId(), id, request)); }

    @DeleteMapping("/long-term-memories/{id}")
    public AjaxResult deleteLongTermMemory(@PathVariable String id)
    { service.deleteLongTermMemory(getUserId(), id); return success(); }

    @PostMapping("/memories")
    public AjaxResult change(@RequestBody AppAiMemoryService.Change request)
    { return success(service.change(getUserId(), request)); }

    @GetMapping("/sessions/{id}/summary")
    public AjaxResult summary(@PathVariable String id) { return success(service.summary(getUserId(), id)); }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public AjaxResult invalidJson() { return AjaxResult.error(400, "记忆参数无效"); }
}
