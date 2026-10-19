package com.ruoyi.system.service.app.impl;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.github.pagehelper.PageHelper;
import com.github.pagehelper.PageInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.app.AppJob;
import com.ruoyi.system.mapper.app.AppJobFavoriteMapper;
import com.ruoyi.system.service.app.IAppJobFavoriteService;

@Service
public class AppJobFavoriteServiceImpl implements IAppJobFavoriteService
{
    @Autowired
    private AppJobFavoriteMapper favoriteMapper;

    @Override
    public boolean isFavorited(Long userId, Long positionId)
    {
        return Boolean.TRUE.equals(favoriteMapper.isFavorited(userId, positionId));
    }

    @Override
    @Transactional
    public boolean setFavorited(Long userId, Long positionId, boolean favorited)
    {
        if (favorited)
        {
            if (favoriteMapper.lockAvailablePosition(positionId) == null)
            {
                throw new ServiceException("职位不存在或暂不可收藏", 404);
            }
            favoriteMapper.favorite(userId, positionId);
        }
        else
        {
            // 即使岗位下架或删除，本人仍可清除原来的收藏。
            favoriteMapper.unfavorite(userId, positionId);
        }
        return isFavorited(userId, positionId);
    }

    @Override
    public Map<String, Object> selectFavorites(Long userId, Integer page, Integer size)
    {
        PageHelper.startPage(page, size);
        List<AppJob> items = favoriteMapper.selectFavorites(userId);
        PageInfo<AppJob> info = new PageInfo<>(items);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("items", items);
        result.put("page", page);
        result.put("size", size);
        result.put("total", info.getTotal());
        result.put("hasNext", (long) page * size < info.getTotal());
        return result;
    }
}
