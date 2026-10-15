package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.system.mapper.AdSlotMapper;
import com.ruoyi.system.domain.AdSlot;
import com.ruoyi.system.service.IAdSlotService;

/**
 * 广告位管理Service业务层处理
 *
 * @author TQY
 */
@Service
public class AdSlotServiceImpl implements IAdSlotService
{
    @Autowired
    private AdSlotMapper adSlotMapper;

    /**
     * 查询广告位管理
     *
     * @param slotCode 广告位编码
     * @return 广告位管理
     */
    @Override
    public AdSlot selectAdSlotBySlotCode(String slotCode)
    {
        return adSlotMapper.selectAdSlotBySlotCode(slotCode);
    }

    /**
     * 查询广告位管理列表
     *
     * @param adSlot 广告位管理
     * @return 广告位管理
     */
    @Override
    public List<AdSlot> selectAdSlotList(AdSlot adSlot)
    {
        return adSlotMapper.selectAdSlotList(adSlot);
    }

    /**
     * 新增广告位管理
     *
     * @param adSlot 广告位管理
     * @return 结果
     */
    @Override
    public int insertAdSlot(AdSlot adSlot)
    {
        adSlot.setCreateBy(SecurityUtils.getUsername());
        return adSlotMapper.insertAdSlot(adSlot);
    }

    /**
     * 修改广告位管理
     *
     * @param adSlot 广告位管理
     * @return 结果
     */
    @Override
    public int updateAdSlot(AdSlot adSlot)
    {
        adSlot.setUpdateBy(SecurityUtils.getUsername());
        return adSlotMapper.updateAdSlot(adSlot);
    }

    /**
     * 批量删除广告位管理
     *
     * @param slotCodes 需要删除的广告位编码
     * @return 结果
     */
    @Override
    public int deleteAdSlotBySlotCodes(String[] slotCodes)
    {
        return adSlotMapper.deleteAdSlotBySlotCodes(slotCodes);
    }

    /**
     * 删除广告位管理信息
     *
     * @param slotCode 广告位编码
     * @return 结果
     */
    @Override
    public int deleteAdSlotBySlotCode(String slotCode)
    {
        return adSlotMapper.deleteAdSlotBySlotCode(slotCode);
    }

    /**
     * 修改广告位状态
     *
     * @param adSlot 广告位管理
     * @return 结果
     */
    @Override
    public int updateAdSlotStatus(AdSlot adSlot)
    {
        adSlot.setUpdateBy(SecurityUtils.getUsername());
        return adSlotMapper.updateAdSlotStatus(adSlot);
    }
}
