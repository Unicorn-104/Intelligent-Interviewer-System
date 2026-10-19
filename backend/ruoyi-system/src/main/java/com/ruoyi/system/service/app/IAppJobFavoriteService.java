package com.ruoyi.system.service.app;

import java.util.Map;

public interface IAppJobFavoriteService
{
    boolean isFavorited(Long userId, Long positionId);

    boolean setFavorited(Long userId, Long positionId, boolean favorited);

    Map<String, Object> selectFavorites(Long userId, Integer page, Integer size);
}
