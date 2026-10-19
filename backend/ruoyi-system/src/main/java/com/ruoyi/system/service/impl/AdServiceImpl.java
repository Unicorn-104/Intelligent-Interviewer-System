package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.SecurityUtils;
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
     * @param advertId 广告管理主键
     * @return 广告管理
     */
    @Override
    public Ad selectAdByAdvertId(Long advertId)
    {
        return adMapper.selectAdByAdvertId(advertId);
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
        ad.setCreateBy(SecurityUtils.getUsername());
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
        ad.setUpdateBy(SecurityUtils.getUsername());
        return adMapper.updateAd(ad);
    }

    /**
     * 批量删除广告管理
     *
     * @param advertIds 需要删除的广告管理主键
     * @return 结果
     */
    @Override
    public int deleteAdByAdvertIds(Long[] advertIds)
    {
        return adMapper.deleteAdByAdvertIds(advertIds);
    }

    /**
     * 删除广告管理信息
     *
     * @param advertId 广告管理主键
     * @return 结果
     */
    @Override
    public int deleteAdByAdvertId(Long advertId)
    {
        return adMapper.deleteAdByAdvertId(advertId);
    }

    /**
     * 修改广告状态
     *
     * @param ad 广告管理
     * @return 结果
     */
    @Override
    public int updateAdStatus(Ad ad)
    {
        ad.setUpdateBy(SecurityUtils.getUsername());
        return adMapper.updateAdStatus(ad);
    }
}
