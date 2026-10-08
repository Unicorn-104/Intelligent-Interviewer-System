package com.ruoyi.system.mapper.app;

import com.ruoyi.system.domain.app.AppUserProfile;

/**
 * C 端用户个人中心数据访问。
 */
public interface AppUserProfileMapper
{
    AppUserProfile selectProfileByUserId(Long userId);

    int updateProfile(AppUserProfile profile);
}
