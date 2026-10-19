package com.ruoyi.web.controller.app;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.app.IAppCompanyService;

/** 求职者企业主页与企业收藏，登录用户从安全上下文获取。 */
@Validated
@RestController
@RequestMapping("/app/companies")
public class AppCompanyController extends BaseController
{
    @Autowired private IAppCompanyService companyService;

    public record FollowRequest(@NotNull Boolean followed) { }

    @GetMapping("/{companyId}")
    public AjaxResult detail(@PathVariable @Positive Long companyId)
    {
        return success(companyService.selectCompany(getUserId(), companyId));
    }

    @GetMapping("/{companyId}/jobs")
    public AjaxResult jobs(@PathVariable @Positive Long companyId,
                          @RequestParam(defaultValue = "1") @Min(1) Integer page,
                          @RequestParam(defaultValue = "10") @Min(1) @Max(100) Integer size)
    {
        return success(companyService.selectJobs(getUserId(), companyId, page, size));
    }

    @PutMapping("/{companyId}/follow")
    public AjaxResult follow(@PathVariable @Positive Long companyId, @Valid @RequestBody FollowRequest request)
    {
        return success(java.util.Map.of("followed", companyService.setFollowed(getUserId(), companyId, request.followed())));
    }

    @GetMapping("/favorites")
    public AjaxResult favorites(@RequestParam(defaultValue = "1") @Min(1) Integer page,
                               @RequestParam(defaultValue = "20") @Min(1) @Max(100) Integer size)
    {
        return success(companyService.selectFavorites(getUserId(), page, size));
    }
}
