package com.ruoyi.web.controller.common;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.SmsCodeBody;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.framework.web.service.SmsCodeService;
import com.ruoyi.system.service.ISysUserService;

/**
 * 手机短信验证码操作处理。
 */
@RestController
@RequestMapping("/sms")
public class SmsController extends BaseController
{
    @Autowired
    private SmsCodeService smsCodeService;

    @Autowired
    private ISysUserService userService;

    @PostMapping("/code")
    public AjaxResult sendCode(@RequestBody SmsCodeBody body)
    {
        String phone = body.getPhone();
        String scene = StringUtils.isEmpty(body.getScene()) ? "login" : body.getScene();
        smsCodeService.validatePhone(phone);

        SysUser user = userService.selectUserByPhone(phone.trim());
        if ("register".equals(scene) && user != null)
        {
            return error("该手机号已注册");
        }
        if ("login".equals(scene) && user == null)
        {
            return error("该手机号尚未注册");
        }

        AjaxResult ajax = success();
        String devCode = smsCodeService.sendCode(phone, scene);
        if (StringUtils.isNotEmpty(devCode))
        {
            ajax.put("devCode", devCode);
        }
        return ajax;
    }
}
