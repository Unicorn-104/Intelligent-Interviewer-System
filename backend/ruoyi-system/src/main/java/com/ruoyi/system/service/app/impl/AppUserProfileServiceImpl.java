package com.ruoyi.system.service.app.impl;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.app.AppUserProfile;
import com.ruoyi.system.mapper.app.AppUserProfileMapper;
import com.ruoyi.system.service.ISysUserService;
import com.ruoyi.system.service.app.IAppUserProfileService;

/**
 * C 端用户个人中心服务实现。
 */
@Service
public class AppUserProfileServiceImpl implements IAppUserProfileService
{
    @Autowired
    private AppUserProfileMapper profileMapper;

    @Autowired
    private ISysUserService userService;

    @Autowired
    private com.ruoyi.enterprise.mapper.JobPreferenceMapper jobPreferenceMapper;

    @Override
    public AppUserProfile selectProfileByUserId(Long userId)
    {
        AppUserProfile profile = profileMapper.selectProfileByUserId(userId);
        if (profile == null)
        {
            throw new ServiceException("用户资料不存在");
        }
        return profile;
    }

    @Override
    @Transactional
    public int updateProfile(AppUserProfile profile)
    {
        profile.validateSalary();
        SysUser user = userService.selectUserById(profile.getUserId());
        if (user == null)
        {
            throw new ServiceException("用户资料不存在");
        }

        user.setPhonenumber(profile.getPhonenumber());
        user.setEmail(profile.getEmail());
        if (StringUtils.isNotEmpty(profile.getPhonenumber()) && !userService.checkPhoneUnique(user))
        {
            throw new ServiceException("手机号码已存在");
        }
        if (StringUtils.isNotEmpty(profile.getEmail()) && !userService.checkEmailUnique(user))
        {
            throw new ServiceException("邮箱账号已存在");
        }
        int changed = profileMapper.updateProfile(profile);
        if (changed > 0 && profile.isSalaryProvided()) jobPreferenceMapper.saveSalary(profile);
        return changed;
    }
}
