package com.ruoyi.web.controller.app;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.service.app.IAppJobService;

/** C-App 首页、岗位搜索与投递接口。 */
@RestController
@RequestMapping("/app")
public class AppJobController extends BaseController
{
    @Autowired
    private IAppJobService jobService;

    @GetMapping("/home")
    public AjaxResult home(@RequestParam(required = false) String filter)
    {
        return success(jobService.selectHomeData(getUserId(), filter));
    }

    @GetMapping("/jobs")
    public AjaxResult jobs(@RequestParam(required = false) String keyword,
                           @RequestParam(required = false) String filter,
                           @RequestParam(required = false, defaultValue = "20") Integer limit)
    {
        return success(jobService.selectJobs(getUserId(), keyword, filter, limit));
    }

    @Log(title = "C端岗位投递", businessType = BusinessType.INSERT)
    @PostMapping("/jobs/{positionId}/apply")
    public AjaxResult apply(@PathVariable Long positionId)
    {
        jobService.apply(getUserId(), positionId);
        return success("投递成功");
    }
}
