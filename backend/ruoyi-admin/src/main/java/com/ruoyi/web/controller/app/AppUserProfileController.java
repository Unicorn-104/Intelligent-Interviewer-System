package com.ruoyi.web.controller.app;

import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.framework.web.service.TokenService;
import com.ruoyi.system.domain.app.AppUserProfile;
import com.ruoyi.system.service.app.IAppUserProfileService;

/**
 * C-App 个人中心接口。
 */
@RestController
@RequestMapping("/app/profile")
public class AppUserProfileController extends BaseController
{
    @Autowired
    private IAppUserProfileService profileService;

    @Autowired
    private TokenService tokenService;

    @GetMapping
    public AjaxResult profile()
    {
        return success(profileService.selectProfileByUserId(getUserId()));
    }

    @Log(title = "C端个人资料", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult updateProfile(@Valid @RequestBody AppUserProfile profile)
    {
        LoginUser loginUser = getLoginUser();
        profile.setUserId(loginUser.getUserId());
        profile.setUpdateBy(SecurityUtils.getUsername());
        if (profileService.updateProfile(profile) <= 0)
        {
            return error("修改个人资料失败");
        }

        loginUser.getUser().setNickName(profile.getNickName());
        loginUser.getUser().setEmail(profile.getEmail());
        loginUser.getUser().setPhonenumber(profile.getPhonenumber());
        loginUser.getUser().setSex(profile.getSex());
        loginUser.getUser().setRemark(profile.getRemark());
        tokenService.setLoginUser(loginUser);
        return success(profileService.selectProfileByUserId(loginUser.getUserId()));
    }
}
