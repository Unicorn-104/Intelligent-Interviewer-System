package com.ruoyi.system.mapper;

import java.util.List;
import com.ruoyi.system.domain.Ad;

/**
 * 广告管理Mapper接口
 *
 * @author TQY
 */
public interface AdMapper
{
    /**
     * 查询广告管理
     *
     * @param advertId 广告管理主键
     * @return 广告管理
     */
    public Ad selectAdByAdvertId(Long advertId);

    /**
     * 查询广告管理列表
     *
     * @param ad 广告管理
     * @return 广告管理集合
     */
    public List<Ad> selectAdList(Ad ad);

    /**
     * 新增广告管理
     *
     * @param ad 广告管理
     * @return 结果
     */
    public int insertAd(Ad ad);

    /**
     * 修改广告管理
     *
     * @param ad 广告管理
     * @return 结果
     */
    public int updateAd(Ad ad);

    /**
     * 删除广告管理
     *
     * @param advertId 广告管理主键
     * @return 结果
     */
    public int deleteAdByAdvertId(Long advertId);

    /**
     * 批量删除广告管理
     *
     * @param advertIds 需要删除的数据主键集合
     * @return 结果
     */
    public int deleteAdByAdvertIds(Long[] advertIds);

    /**
     * 修改广告状态
     *
     * @param ad 广告管理
     * @return 结果
     */
    public int updateAdStatus(Ad ad);
}
