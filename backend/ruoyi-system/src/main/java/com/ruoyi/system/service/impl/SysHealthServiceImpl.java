package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.system.domain.SysHealth;
import com.ruoyi.system.mapper.SysHealthMapper;
import com.ruoyi.system.service.ISysHealthService;

/**
 * 服务健康监控Service业务层处理
 *
 * @author TQY
 */
@Service
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
        sysHealth.setSthCheckTime(DateUtils.getNowDate());
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
