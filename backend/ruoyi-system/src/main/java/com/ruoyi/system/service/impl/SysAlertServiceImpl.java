package com.ruoyi.system.service.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.system.domain.SysAlert;
import com.ruoyi.system.mapper.SysAlertMapper;
import com.ruoyi.system.service.ISysAlertService;

/**
 * 鍛婅璁板綍Service涓氬姟灞傚鐞? *
 * @author TQY
 */
@Service
@Transactional(rollbackFor = Exception.class)
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
