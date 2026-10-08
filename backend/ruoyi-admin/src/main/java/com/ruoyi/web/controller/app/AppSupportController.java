package com.ruoyi.web.controller.app;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.domain.app.AppFeedbackRequest;
import com.ruoyi.system.service.app.IAppSupportService;

/** C-App 帮助中心、问题反馈与客服咨询入口。 */
@RestController
@RequestMapping("/app/support")
public class AppSupportController extends BaseController
{
    @Autowired
    private IAppSupportService supportService;

    @GetMapping("/help-articles")
    public AjaxResult helpArticles(@RequestParam(required = false) String keyword,
                                   @RequestParam(required = false) String category,
                                   @RequestParam(required = false, defaultValue = "50") Integer limit)
    {
        return success(supportService.selectHelpArticles(keyword, category, limit));
    }

    @GetMapping("/feedback")
    public AjaxResult feedback(@RequestParam(required = false, defaultValue = "20") Integer limit)
    {
        return success(supportService.selectFeedbacks(getUserId(), limit));
    }

    @Log(title = "C端问题反馈", businessType = BusinessType.INSERT)
    @PostMapping("/feedback")
    public AjaxResult submitFeedback(@Valid @RequestBody AppFeedbackRequest request)
    {
        supportService.submitFeedback(getUserId(), request);
        return success("反馈已提交");
    }
}
