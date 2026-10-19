package com.ruoyi.system.mapper.app;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.app.AppJob;

/** 岗位收藏复用 t_usr_interest，固定对象类型为 1。 */
public interface AppJobFavoriteMapper
{
    Boolean isFavorited(@Param("userId") Long userId, @Param("positionId") Long positionId);

    Long lockAvailablePosition(@Param("positionId") Long positionId);

    int favorite(@Param("userId") Long userId, @Param("positionId") Long positionId);

    int unfavorite(@Param("userId") Long userId, @Param("positionId") Long positionId);

    List<AppJob> selectFavorites(@Param("userId") Long userId);
}
