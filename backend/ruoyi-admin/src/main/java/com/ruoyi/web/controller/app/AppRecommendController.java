package com.ruoyi.web.controller.app;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.domain.app.AppRecommendRequest;
import com.ruoyi.system.service.app.IAppRecommendService;

/** C-App AI 简历推荐接口。 */
@RestController
@RequestMapping("/app/recommend")
public class AppRecommendController extends BaseController
{
    @Autowired
    private IAppRecommendService recommendService;

    @PostMapping
    public AjaxResult recommend(@Valid @RequestBody AppRecommendRequest request)
    {
        return success(recommendService.recommend(getUserId(), request));
    }
}
