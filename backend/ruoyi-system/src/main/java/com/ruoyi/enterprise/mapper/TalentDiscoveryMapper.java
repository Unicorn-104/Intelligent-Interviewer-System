package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;

/** 平台人才发现，只读公开基础字段，不依赖企业人才记录。 */
public interface TalentDiscoveryMapper
{
    List<Map<String,Object>> selectUsers(@Param("keyword") String keyword,
        @Param("direction") String direction, @Param("currentStatus") Integer currentStatus,
        @Param("criteria") TalentSearchCriteria criteria);
    Map<String,Object> selectUser(@Param("userId") Long userId);
    List<String> selectDirections();
    List<String> selectCities(@Param("cityType") String cityType);
}
