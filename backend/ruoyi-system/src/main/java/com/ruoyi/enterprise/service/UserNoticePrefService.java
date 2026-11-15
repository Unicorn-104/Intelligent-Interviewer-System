package com.ruoyi.enterprise.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.enterprise.domain.NoticePref;
import com.ruoyi.enterprise.mapper.UserNoticePrefMapper;

/** 企业端用户站内通知偏好读写；无记录时按全部开启处理。 */
@Service
public class UserNoticePrefService
{
    @Autowired private UserNoticePrefMapper mapper;

    public NoticePref get(Long userId)
    {
        NoticePref pref = userId == null || userId <= 0 ? null : mapper.select(userId);
        return pref == null ? new NoticePref() : pref;
    }

    public void save(Long userId, NoticePref pref)
    {
        mapper.upsert(userId, pref);
    }
}
