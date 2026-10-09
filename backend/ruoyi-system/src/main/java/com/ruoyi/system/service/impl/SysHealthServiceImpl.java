package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.system.domain.SysHealth;
import com.ruoyi.system.mapper.SysHealthMapper;
import com.ruoyi.system.service.ISysHealthService;

/**
 * 鏈嶅姟鍋ュ悍鐩戞帶Service涓氬姟灞傚鐞? *
 * @author TQY
 */
@Service
@Transactional(rollbackFor = Exception.class)
public class SysHealthServiceImpl implements ISysHealthService
{
    @Autowired
    private SysHealthMapper sysHealthMapper;

    @Override
    public SysHealth selectSysHealthBySthId(Long sthId)
    {
        return sysHealthMapper.selectSysHealthBySthId(sthId);
    }

    @Override
    public List<SysHealth> selectSysHealthList(SysHealth sysHealth)
    {
        return sysHealthMapper.selectSysHealthList(sysHealth);
    }

    @Override
    public int insertSysHealth(SysHealth sysHealth)
    {
        sysHealth.setSthCheckedAt(DateUtils.getNowDate());
        return sysHealthMapper.insertSysHealth(sysHealth);
    }

    @Override
    public int updateSysHealth(SysHealth sysHealth)
    {
        return sysHealthMapper.updateSysHealth(sysHealth);
    }

    @Override
    public int deleteSysHealthBySthId(Long sthId)
    {
        return sysHealthMapper.deleteSysHealthBySthId(sthId);
    }
}
