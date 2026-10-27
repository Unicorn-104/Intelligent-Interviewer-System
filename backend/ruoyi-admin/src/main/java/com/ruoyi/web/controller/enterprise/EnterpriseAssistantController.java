package com.ruoyi.web.controller.enterprise;

import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import org.springframework.http.converter.HttpMessageNotReadableException;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.EnterpriseAssistantService;

/** All identities come from authentication; never accept user/company IDs in a request body. */
@RestController
@RequestMapping("/enterprise/assistant")
public class EnterpriseAssistantController extends BaseController
{
    private final EnterpriseAssistantService service;
    public EnterpriseAssistantController(EnterpriseAssistantService service) {this.service=service;}
    public record SendRequest(String requestId,String content) { }
    @GetMapping("/sessions") public AjaxResult sessions(@RequestParam(required=false) Long before)
    {return success(service.sessions(getUserId(),before));}
    @PostMapping("/sessions") public AjaxResult create() {return success(service.create(getUserId()));}
    @GetMapping("/sessions/{id}/messages") public AjaxResult messages(@PathVariable Long id,@RequestParam(required=false) Long before)
    {return success(service.messages(getUserId(),id,before));}
    @PostMapping("/sessions/{id}/runs") public AjaxResult start(@PathVariable Long id,@RequestBody SendRequest body)
    {return success(service.start(getUserId(),id,body.requestId(),body.content()));}
    @GetMapping("/sessions/{id}/requests/{requestId}") public AjaxResult request(@PathVariable Long id,@PathVariable String requestId)
    {return success(service.request(getUserId(),id,requestId));}
    @GetMapping("/runs/{id}") public AjaxResult run(@PathVariable Long id) {return success(service.run(getUserId(),id));}
    @GetMapping(value="/runs/{id}/events", produces="text/event-stream;charset=UTF-8")
    public SseEmitter events(@PathVariable Long id, jakarta.servlet.http.HttpServletResponse response)
    {
        response.setHeader("Cache-Control", "no-store");
        response.setHeader("X-Accel-Buffering", "no");
        return service.events(getUserId(), id);
    }
    @PostMapping("/runs/{id}/cancel") public AjaxResult cancel(@PathVariable Long id) {return success(service.cancel(getUserId(),id));}
    @DeleteMapping("/sessions/{id}") public AjaxResult delete(@PathVariable Long id) {service.delete(getUserId(),id);return success();}
    @ExceptionHandler(HttpMessageNotReadableException.class) public AjaxResult invalid() {return AjaxResult.error(400,"消息格式无效");}
}
