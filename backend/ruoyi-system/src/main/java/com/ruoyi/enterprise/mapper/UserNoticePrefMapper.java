package com.ruoyi.enterprise.mapper;

import org.apache.ibatis.annotations.Param;
import com.ruoyi.enterprise.domain.NoticePref;

public interface UserNoticePrefMapper
{
    NoticePref select(@Param("userId") Long userId);

    int upsert(@Param("userId") Long userId, @Param("pref") NoticePref pref);
}
