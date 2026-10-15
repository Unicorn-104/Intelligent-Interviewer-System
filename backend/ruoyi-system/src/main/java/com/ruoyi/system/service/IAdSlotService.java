package com.ruoyi.system.service;

import java.util.List;
import com.ruoyi.system.domain.AdSlot;

/**
 * 广告位管理Service接口
 *
 * @author TQY
 */
public interface IAdSlotService
{
    /**
     * 查询广告位管理
     *
     * @param slotCode 广告位编码
     * @return 广告位管理
     */
    public AdSlot selectAdSlotBySlotCode(String slotCode);

    /**
     * 查询广告位管理列表
     *
     * @param adSlot 广告位管理
     * @return 广告位管理集合
     */
    public List<AdSlot> selectAdSlotList(AdSlot adSlot);

    /**
     * 新增广告位管理
     *
     * @param adSlot 广告位管理
     * @return 结果
     */
    public int insertAdSlot(AdSlot adSlot);

    /**
     * 修改广告位管理
     *
     * @param adSlot 广告位管理
     * @return 结果
     */
    public int updateAdSlot(AdSlot adSlot);

    /**
     * 批量删除广告位管理
     *
     * @param slotCodes 需要删除的广告位编码
     * @return 结果
     */
    public int deleteAdSlotBySlotCodes(String[] slotCodes);

    /**
     * 删除广告位管理信息
     *
     * @param slotCode 广告位编码
     * @return 结果
     */
    public int deleteAdSlotBySlotCode(String slotCode);

    /**
     * 修改广告位状态
     *
     * @param adSlot 广告位管理
     * @return 结果
     */
    public int updateAdSlotStatus(AdSlot adSlot);
}
