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
import com.ruoyi.framework.web.service.AppSecurityService;
import com.ruoyi.framework.web.service.TokenService;
import com.ruoyi.system.domain.app.AppSecurityEmailRequest;
import com.ruoyi.system.domain.app.AppSecurityPhoneRequest;

/**
 * 求职者端账号安全接口。
 */
@RestController
@RequestMapping("/app/security")
public class AppSecurityController extends BaseController
{
    @Autowired
    private AppSecurityService securityService;

    @Autowired
    private TokenService tokenService;

    @GetMapping
    public AjaxResult profile()
    {
        return success(securityService.selectProfile(getUserId()));
    }

    @Log(title = "求职者端绑定手机", businessType = BusinessType.UPDATE)
    @PutMapping("/phone")
    public AjaxResult updatePhone(@Valid @RequestBody AppSecurityPhoneRequest request)
    {
        LoginUser loginUser = getLoginUser();
        loginUser.getUser().setPhonenumber(
                securityService.updatePhone(loginUser.getUserId(), request.getPhone(), request.getSmsCode()).getPhonenumber());
        tokenService.setLoginUser(loginUser);
        return success(securityService.selectProfile(loginUser.getUserId()));
    }

    @Log(title = "求职者端绑定邮箱", businessType = BusinessType.UPDATE)
    @PutMapping("/email")
    public AjaxResult updateEmail(@Valid @RequestBody AppSecurityEmailRequest request)
    {
        LoginUser loginUser = getLoginUser();
        loginUser.getUser().setEmail(
                securityService.updateEmail(loginUser.getUserId(), request.getEmail(), request.getCurrentPassword()).getEmail());
        tokenService.setLoginUser(loginUser);
        return success(securityService.selectProfile(loginUser.getUserId()));
    }
}
