package com.ruoyi.web.controller.system;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.ISurveyService;

/**
 * 候选人端 - 满意度调研匿名填写
 *
 * <p>候选人通过 HR 发送的带令牌链接进入填写页，无需登录：
 * 按令牌读取问卷题目、提交作答并回写回收记录。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/system/survey/fill")
public class SurveyFillController extends BaseController
{
    @Autowired
    private ISurveyService surveyService;

    /**
     * 按匿名令牌读取问卷填写内容
     */
    @Anonymous
    @GetMapping
    public AjaxResult form(@RequestParam(required = false) String token)
    {
        return success(surveyService.getFillForm(token));
    }

    /**
     * 按匿名令牌提交问卷作答
     */
    @Anonymous
    @PostMapping
    public AjaxResult submit(@RequestBody Map<String, Object> body)
    {
        Object token = body.get("token");
        return success(surveyService.submitFill(token == null ? null : String.valueOf(token), body));
    }
}
