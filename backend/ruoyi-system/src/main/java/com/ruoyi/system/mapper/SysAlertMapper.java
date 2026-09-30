package com.ruoyi.system.mapper;

import java.util.List;
import com.ruoyi.system.domain.SysAlert;

/**
 * 告警记录Mapper接口
 *
 * @author TQY
 */
public interface SysAlertMapper
{
    public SysAlert selectSysAlertBySalId(Long salId);

    public List<SysAlert> selectSysAlertList(SysAlert sysAlert);

    public int insertSysAlert(SysAlert sysAlert);
}
