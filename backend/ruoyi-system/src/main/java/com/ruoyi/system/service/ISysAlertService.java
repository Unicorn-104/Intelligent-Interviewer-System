package com.ruoyi.system.service;

import java.util.List;
import com.ruoyi.system.domain.SysAlert;

/**
 * 告警记录Service接口
 *
 * @author TQY
 */
public interface ISysAlertService
{
    public SysAlert selectSysAlertBySalId(Long salId);

    public List<SysAlert> selectSysAlertList(SysAlert sysAlert);

    public int insertSysAlert(SysAlert sysAlert);
}
