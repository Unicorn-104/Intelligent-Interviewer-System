package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.system.mapper.AdMapper;
import com.ruoyi.system.domain.Ad;
import com.ruoyi.system.service.IAdService;

/**
 * 广告管理Service业务层处理
 *
 * @author TQY
 */
@Service
public class AdServiceImpl implements IAdService
{
    @Autowired
    private AdMapper adMapper;

    /**
     * 查询广告管理
     *
     * @param adId 广告管理主键
     * @return 广告管理
     */
    @Override
    public Ad selectAdByAdId(Long adId)
    {
        return adMapper.selectAdByAdId(adId);
    }

    /**
     * 查询广告管理列表
     *
     * @param ad 广告管理
     * @return 广告管理
     */
    @Override
    public List<Ad> selectAdList(Ad ad)
    {
        return adMapper.selectAdList(ad);
    }

    /**
     * 新增广告管理
     *
     * @param ad 广告管理
     * @return 结果
     */
    @Override
    public int insertAd(Ad ad)
    {
        return adMapper.insertAd(ad);
    }

    /**
     * 修改广告管理
     *
     * @param ad 广告管理
     * @return 结果
     */
    @Override
    public int updateAd(Ad ad)
    {
        return adMapper.updateAd(ad);
    }

    /**
     * 批量删除广告管理
     *
     * @param adIds 需要删除的广告管理主键
     * @return 结果
     */
    @Override
    public int deleteAdByAdIds(Long[] adIds)
    {
        return adMapper.deleteAdByAdIds(adIds);
    }

    /**
     * 删除广告管理信息
     *
     * @param adId 广告管理主键
     * @return 结果
     */
    @Override
    public int deleteAdByAdId(Long adId)
    {
        return adMapper.deleteAdByAdId(adId);
    }
}
