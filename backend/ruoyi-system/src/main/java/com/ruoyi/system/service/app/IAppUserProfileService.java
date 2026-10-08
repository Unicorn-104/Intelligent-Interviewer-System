package com.ruoyi.system.service.app;

import com.ruoyi.system.domain.app.AppUserProfile;

/**
 * C 端用户个人中心服务。
 */
public interface IAppUserProfileService
{
    AppUserProfile selectProfileByUserId(Long userId);

    int updateProfile(AppUserProfile profile);
}
