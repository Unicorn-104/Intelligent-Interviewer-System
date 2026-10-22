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

    @GetMapping("/memories")
    public AjaxResult read() { return success(service.read(getUserId())); }

    @PostMapping("/memories")
    public AjaxResult change(@RequestBody AppAiMemoryService.Change request)
    { return success(service.change(getUserId(), request)); }

    @GetMapping("/sessions/{id}/summary")
    public AjaxResult summary(@PathVariable String id) { return success(service.summary(getUserId(), id)); }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public AjaxResult invalidJson() { return AjaxResult.error(400, "记忆参数无效"); }
}
