package com.ruoyi.web.controller.app;

import jakarta.validation.Valid;
import java.util.List;
import org.springframework.validation.BindingResult;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.app.ai.AgentRunRequest;
import com.ruoyi.system.service.app.ai.AppAiService;

/** AI conversations are separate from HR conversations and never accept caller-supplied user IDs. */
@RestController
@RequestMapping("/app/ai")
public class AppAiController extends BaseController
{
    private final AppAiService service;
    public AppAiController(AppAiService service) { this.service = service; }

    @GetMapping("/sessions")
    public AjaxResult sessions(@RequestParam(required = false) String before)
    { return success(service.sessions(getUserId(), before)); }

    @PostMapping("/sessions")
    public AjaxResult create() { return success(service.createSession(getUserId())); }

    public record RenameRequest(String title) { }

    @PostMapping("/sessions/{id}/rename")
    public AjaxResult rename(@PathVariable String id, @RequestBody RenameRequest request)
    { return success(service.rename(getUserId(), id, request == null ? null : request.title())); }

    public record PinRequest(Boolean pinned) { }

    @PostMapping("/sessions/{id}/pin")
    public AjaxResult pin(@PathVariable String id, @RequestBody PinRequest request)
    { return success(service.pin(getUserId(), id, request != null && Boolean.TRUE.equals(request.pinned()))); }

    @DeleteMapping("/sessions/{id}")
    public AjaxResult delete(@PathVariable String id)
    { service.delete(getUserId(), id); return success(); }

    public record BatchDeleteRequest(List<String> ids) { }

    @PostMapping("/sessions/batch-delete")
    public AjaxResult batchDelete(@RequestBody BatchDeleteRequest request)
    { service.deleteBatch(getUserId(), request == null ? null : request.ids()); return success(); }

    @GetMapping("/sessions/{id}/messages")
    public AjaxResult messages(@PathVariable String id, @RequestParam(required = false) Long before)
    { return success(service.messages(getUserId(), id, before)); }

    @PostMapping("/sessions/{id}/runs")
    public AjaxResult start(@PathVariable String id, @Valid @RequestBody AgentRunRequest request, BindingResult binding)
    {
        // Do not let validation exceptions log rejected private message content.
        if (binding.hasErrors()) return AjaxResult.error(400, "消息参数无效");
        return success(service.start(getUserId(), id, request));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public AjaxResult invalidJson() { return AjaxResult.error(400, "消息格式无效"); }

    @GetMapping("/runs/{id}")
    public AjaxResult run(@PathVariable String id) { return success(service.run(getUserId(), id)); }

    @PostMapping("/runs/{id}/cancel")
    public AjaxResult cancel(@PathVariable String id) { service.cancel(getUserId(), id); return success(); }

    @GetMapping(value = "/runs/{id}/events", produces = "text/event-stream")
    public SseEmitter events(@PathVariable String id, @RequestParam(defaultValue = "0") long after,
            jakarta.servlet.http.HttpServletResponse response)
    {
        response.setHeader("Cache-Control", "no-cache");
        response.setHeader("X-Accel-Buffering", "no");
        return service.events(getUserId(), id, after);
    }
}
