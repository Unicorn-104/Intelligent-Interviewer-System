package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.system.domain.SysAlert;
import com.ruoyi.system.mapper.SysAlertMapper;
import com.ruoyi.system.service.ISysAlertService;

/**
 * 告警记录Service业务层处理
 *
 * @author TQY
 */
@Service
public class SysAlertServiceImpl implements ISysAlertService
{
    @Autowired
    private SysAlertMapper sysAlertMapper;

    @Override
    public SysAlert selectSysAlertBySalId(Long salId)
    {
        return sysAlertMapper.selectSysAlertBySalId(salId);
    }

    @Override
    public List<SysAlert> selectSysAlertList(SysAlert sysAlert)
    {
        return sysAlertMapper.selectSysAlertList(sysAlert);
    }

    @Override
    public int insertSysAlert(SysAlert sysAlert)
    {
        sysAlert.setSalCreatedAt(DateUtils.getNowDate());
        return sysAlertMapper.insertSysAlert(sysAlert);
    }
}
