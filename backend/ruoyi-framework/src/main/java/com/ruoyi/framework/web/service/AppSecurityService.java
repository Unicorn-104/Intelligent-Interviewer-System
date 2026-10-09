package com.ruoyi.framework.web.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.app.AppSecurityProfile;
import com.ruoyi.system.service.ISysUserService;

/**
 * 求职者端账号安全业务。
 */
@Service
public class AppSecurityService
{
    private static final String PHONE_SCENE = "bind_phone";

    @Autowired
    private ISysUserService userService;

    @Autowired
    private SmsCodeService smsCodeService;

    public AppSecurityProfile selectProfile(Long userId)
    {
        return toProfile(getUser(userId));
    }

    public SysUser updatePhone(Long userId, String phone, String smsCode)
    {
        String normalizedPhone = phone == null ? "" : phone.trim();
        smsCodeService.validateCode(normalizedPhone, PHONE_SCENE, smsCode);
        SysUser user = getUser(userId);
        SysUser phoneOwner = userService.selectUserByPhone(normalizedPhone);
        if (phoneOwner != null && !userId.equals(phoneOwner.getUserId()))
        {
            throw new ServiceException("该手机号已被其他账号绑定");
        }
        user.setPhonenumber(normalizedPhone);
        if (userService.updateUserProfile(user) <= 0)
        {
            throw new ServiceException("更换绑定手机号失败");
        }
        return userService.selectUserById(userId);
    }

    public SysUser updateEmail(Long userId, String email, String currentPassword)
    {
        SysUser user = getUser(userId);
        if (!SecurityUtils.matchesPassword(currentPassword, user.getPassword()))
        {
            throw new ServiceException("当前密码错误");
        }
        String normalizedEmail = email == null ? "" : email.trim();
        user.setEmail(normalizedEmail);
        if (StringUtils.isNotEmpty(normalizedEmail) && !userService.checkEmailUnique(user))
        {
            throw new ServiceException("该邮箱已被其他账号绑定");
        }
        if (userService.updateUserProfile(user) <= 0)
        {
            throw new ServiceException("更换绑定邮箱失败");
        }
        return userService.selectUserById(userId);
    }

    private SysUser getUser(Long userId)
    {
        SysUser user = userService.selectUserById(userId);
        if (user == null)
        {
            throw new ServiceException("用户不存在");
        }
        return user;
    }

    private AppSecurityProfile toProfile(SysUser user)
    {
        AppSecurityProfile profile = new AppSecurityProfile();
        profile.setUserId(user.getUserId());
        profile.setUserName(user.getUserName());
        profile.setPhonenumber(user.getPhonenumber());
        profile.setEmail(user.getEmail());
        profile.setPwdUpdateDate(user.getPwdUpdateDate());
        profile.setLoginDate(user.getLoginDate());
        return profile;
    }
}
