package com.ruoyi.web.controller.system;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Anonymous;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.model.RegisterBody;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.framework.web.service.SysRegisterService;
import com.ruoyi.system.service.IEnterpriseRegisterService;
import com.ruoyi.system.service.ISysConfigService;

/**
 * 注册验证
 * 
 * @author ruoyi
 */
@RestController
public class SysRegisterController extends BaseController
{
    @Autowired
    private SysRegisterService registerService;

    @Autowired
    private ISysConfigService configService;

    @Autowired
    private IEnterpriseRegisterService enterpriseRegisterService;

    @PostMapping("/register")
    public AjaxResult register(@RequestBody RegisterBody user)
    {
        if (!("true".equals(configService.selectConfigByKey("sys.account.registerUser"))))
        {
            return error("当前系统没有开启注册功能！");
        }
        String msg = registerService.register(user);
        return StringUtils.isEmpty(msg) ? success() : error(msg);
    }

    /**
     * 企业自助注册：注册后企业与账号均处于待审核状态，不自动登录
     */
    @Anonymous
    @PostMapping("/register/enterprise")
    public AjaxResult registerEnterprise(@RequestBody Map<String, Object> body)
    {
        if (configService.selectCaptchaEnabled())
        {
            Object code = body.get("code");
            Object uuid = body.get("uuid");
            if (code == null || StringUtils.isEmpty(code.toString()))
            {
                return error("请输入验证码");
            }
            registerService.validateCaptcha(String.valueOf(body.getOrDefault("username", "")), code.toString(),
                    uuid == null ? null : uuid.toString());
        }
        enterpriseRegisterService.register(body);
        return success("注册成功，请等待平台审核");
    }
}
