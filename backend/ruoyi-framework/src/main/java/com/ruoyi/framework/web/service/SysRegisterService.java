package com.ruoyi.framework.web.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.ruoyi.common.constant.CacheConstants;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.common.constant.UserConstants;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.RegisterBody;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.user.CaptchaException;
import com.ruoyi.common.exception.user.CaptchaExpireException;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.MessageUtils;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.framework.manager.AsyncManager;
import com.ruoyi.framework.manager.factory.AsyncFactory;
import com.ruoyi.system.service.ISysConfigService;
import com.ruoyi.system.service.ISysUserService;
import com.ruoyi.system.mapper.SysRoleMapper;
import com.ruoyi.common.core.domain.entity.SysRole;
import org.springframework.transaction.annotation.Transactional;

/**
 * 注册校验方法
 * 
 * @author ruoyi
 */
@Component
public class SysRegisterService
{
    @Autowired
    private ISysUserService userService;

    @Autowired
    private ISysConfigService configService;

    @Autowired
    private RedisCache redisCache;

    @Autowired
    private SmsCodeService smsCodeService;

    @Autowired
    private SysRoleMapper roleMapper;

    /**
     * 注册
     */
    @Transactional
    public String register(RegisterBody registerBody)
    {
        String msg = "", phone = registerBody.getPhone(), username = registerBody.getUsername(),
                password = registerBody.getPassword();
        SysUser sysUser = new SysUser();

        boolean accountRegister = "account_password".equalsIgnoreCase(registerBody.getRegisterType());
        boolean phoneRegister = !accountRegister && StringUtils.isNotEmpty(phone);
        if (phoneRegister)
        {
            phone = phone.trim();
            smsCodeService.validateCode(phone, "register", registerBody.getSmsCode());
            username = phone;
            sysUser.setUserName(phone);
            sysUser.setPhonenumber(phone);
        }
        else
        {
            username = StringUtils.isEmpty(username) ? "" : username.trim();
            sysUser.setUserName(username);
            // 账号密码注册由用户端单独声明注册方式，不再依赖后台图形验证码页面。
            if (!accountRegister)
            {
                boolean captchaEnabled = configService.selectCaptchaEnabled();
                if (captchaEnabled)
                {
                    validateCaptcha(username, registerBody.getCode(), registerBody.getUuid());
                }
            }
        }

        if (StringUtils.isEmpty(username))
        {
            msg = "用户名不能为空";
        }
        else if (StringUtils.isEmpty(password))
        {
            msg = "用户密码不能为空";
        }
        else if (username.length() < UserConstants.USERNAME_MIN_LENGTH
                || username.length() > UserConstants.USERNAME_MAX_LENGTH)
        {
            msg = "账户长度必须在2到20个字符之间";
        }
        else if (password.length() < UserConstants.PASSWORD_MIN_LENGTH
                || password.length() > UserConstants.PASSWORD_MAX_LENGTH)
        {
            msg = "密码长度必须在5到20个字符之间";
        }
        else if (phoneRegister && !smsCodeService.isValidPhone(phone))
        {
            msg = "请输入正确的手机号";
        }
        else if (phoneRegister && !userService.checkPhoneUnique(sysUser))
        {
            msg = "该手机号已注册";
        }
        else if (!userService.checkUserNameUnique(sysUser))
        {
            msg = "保存用户'" + username + "'失败，注册账号已存在";
        }
        else
        {
            sysUser.setNickName(username);
            sysUser.setUserIdentityType(1);
            sysUser.setPwdUpdateDate(DateUtils.getNowDate());
            sysUser.setPassword(SecurityUtils.encryptPassword(password));
            SysRole candidateRole = roleMapper.checkRoleKeyUnique("biz_4");
            if (candidateRole == null)
            {
                msg = "注册失败，系统未配置求职者角色";
            }
            else if (!userService.registerUser(sysUser))
            {
                msg = "注册失败,请联系系统管理人员";
            }
            else
            {
                userService.insertUserAuth(sysUser.getUserId(), new Long[] { candidateRole.getRoleId() });
                AsyncManager.me().execute(AsyncFactory.recordLogininfor(username, Constants.REGISTER, MessageUtils.message("user.register.success")));
            }
        }
        return msg;
    }

    /**
     * 校验验证码
     * 
     * @param username 用户名
     * @param code 验证码
     * @param uuid 唯一标识
     * @return 结果
     */
    public void validateCaptcha(String username, String code, String uuid)
    {
        String verifyKey = CacheConstants.CAPTCHA_CODE_KEY + StringUtils.nvl(uuid, "");
        String captcha = redisCache.getCacheObject(verifyKey);
        redisCache.deleteObject(verifyKey);
        if (captcha == null)
        {
            throw new CaptchaExpireException();
        }
        if (!code.equalsIgnoreCase(captcha))
        {
            throw new CaptchaException();
        }
    }
}
