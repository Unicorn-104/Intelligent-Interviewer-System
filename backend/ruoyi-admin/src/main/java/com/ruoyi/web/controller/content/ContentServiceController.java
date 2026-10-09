package com.ruoyi.web.controller.content;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;

import java.util.*;

/**
 * 内容服务配置Controller
 */
@RestController
@RequestMapping("/content/service")
public class ContentServiceController extends BaseController {

    @PreAuthorize("@ss.hasPermi('content:service:query')")
    @GetMapping("/config")
    public AjaxResult getConfig() {
        // 返回默认客服配置
        Map<String, Object> config = new HashMap<>();
        config.put("kefuPhone", "400-123-4567");
        config.put("kefuEmail", "support@example.com");
        config.put("kefuWechat", "kefu_service");
        config.put("workTime", "周一至周五 9:00-18:00");
        return AjaxResult.success(config);
    }

    @PreAuthorize("@ss.hasPermi('content:service:edit')")
    @PutMapping("/config")
    public AjaxResult updateConfig(@RequestBody Map<String, Object> body) {
        // 配置保存成功（暂存内存，后续接入数据库）
        return AjaxResult.success();
    }
}
