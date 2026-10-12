package com.ruoyi.web.controller.system;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.IConferenceSignalService;

/**
 * 面试视频会议 WebRTC 信令通道（SSE）
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/system/conference")
public class ConferenceSignalController extends BaseController
{
    @Autowired
    private IConferenceSignalService conferenceSignalService;

    /**
     * 签发一次性信令票据（需登录）
     */
    @PostMapping("/session/{sessionId}/signal/ticket")
    public AjaxResult signalTicket(@PathVariable Long sessionId)
    {
        return success(conferenceSignalService.issueTicket(getUserId(), sessionId));
    }

    /**
     * 建立 SSE 信令通道（匿名 + 票据自校验）
     */
    @Anonymous
    @GetMapping(value = "/signal/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter signalStream(@RequestParam(required = false) String ticket)
    {
        return conferenceSignalService.openStream(ticket);
    }

    /**
     * 向同场次对端转发信令（匿名 + 票据自校验）
     */
    @Anonymous
    @PostMapping("/signal/send")
    public AjaxResult signalSend(@RequestParam(required = false) String ticket, @RequestBody Map<String, Object> body)
    {
        @SuppressWarnings("unchecked")
        Map<String, Object> payload = body.get("payload") instanceof Map ? (Map<String, Object>) body.get("payload") : null;
        conferenceSignalService.relay(ticket, str(body, "type"), payload, longOf(body, "to"));
        return success();
    }

    private String str(Map<String, Object> map, String key)
    {
        Object value = map == null ? null : map.get(key);
        return value == null ? null : value.toString();
    }

    private Long longOf(Map<String, Object> map, String key)
    {
        Object value = map == null ? null : map.get(key);
        if (value == null)
        {
            return null;
        }
        return value instanceof Number ? ((Number) value).longValue() : Long.valueOf(value.toString());
    }
}
