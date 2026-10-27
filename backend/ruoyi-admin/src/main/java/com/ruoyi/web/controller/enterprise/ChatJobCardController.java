package com.ruoyi.web.controller.enterprise;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.ChatJobCardService;
@RestController
@RequestMapping("/enterprise/chat")
public class ChatJobCardController extends BaseController {
 @Autowired private ChatJobCardService cards;
 @GetMapping("/jobs") public AjaxResult jobs(@RequestParam(required=false)String keyword,@RequestParam(defaultValue="1")int page){return success(cards.jobs(getUserId(),keyword,page));}
 public record Send(Long sessionId,Long peerId,Long positionId,String requestId){}
 @PostMapping("/job-cards") public AjaxResult send(@RequestBody Send body){return success(cards.send(getUserId(),body.sessionId(),body.peerId(),body.positionId(),body.requestId()));}
}
