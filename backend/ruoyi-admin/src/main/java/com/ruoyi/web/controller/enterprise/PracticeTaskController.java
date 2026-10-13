package com.ruoyi.web.controller.enterprise;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.IPracticeTaskService;

/**
 * 企业端 - 在线实操环境预加载
 *
 * <p>依据《业务功能分析》UC-11（在线实操环境预加载）：
 * 技术类岗位且面试模式包含实操环节的场次，在准备阶段异步预加载
 * 在线实操考核环境（代码沙箱、云端 IDE），确保候选人正式进入
 * 面试时无需等待环境初始化。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/practice")
public class PracticeTaskController extends BaseController
{
    @Autowired
    private IPracticeTaskService practiceTaskService;

    /**
     * UC-11：预加载在线实操考核环境（模拟即时就绪，P7 对接沙箱服务后异步化）
     */
    @PostMapping("/{sessionId}/preload")
    public AjaxResult preload(@PathVariable("sessionId") Long sessionId)
    {
        return success(practiceTaskService.preload(getUserId(), sessionId));
    }

    /**
     * UC-11：实操环境预加载状态查询
     */
    @GetMapping("/{sessionId}/status")
    public AjaxResult status(@PathVariable("sessionId") Long sessionId)
    {
        return success(practiceTaskService.status(getUserId(), sessionId));
    }
}
