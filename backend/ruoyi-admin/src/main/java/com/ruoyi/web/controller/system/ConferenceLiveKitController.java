package com.ruoyi.web.controller.system;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.ILiveKitTokenService;

/**
 * 视频会议 LiveKit 接入控制器
 * <p>
 * 替代原自研 SSE 信令入口：客户端凭此接口换取 LiveKit 入会令牌，
 * 之后直接与 LiveKit Server 建立 WebSocket 信令与媒体连接。
 *
 * @author YLX
 */
@RestController
@RequestMapping("/system/conference")
public class ConferenceLiveKitController extends BaseController
{
    @Autowired
    private ILiveKitTokenService liveKitTokenService;

    /**
     * 签发指定场次的 LiveKit 入会令牌（企业端与候选人端登录后共用）
     */
    @GetMapping("/livekit-token/{sessionId}")
    public AjaxResult liveKitToken(@PathVariable Long sessionId)
    {
        return success(liveKitTokenService.issueToken(getUserId(), sessionId));
    }
}
