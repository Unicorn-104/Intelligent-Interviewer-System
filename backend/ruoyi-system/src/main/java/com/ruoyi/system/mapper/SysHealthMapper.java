package com.ruoyi.system.mapper;

import java.util.List;
import com.ruoyi.system.domain.SysHealth;

/**
 * 服务健康监控Mapper接口
 *
 * @author TQY
 */
public interface SysHealthMapper
{
    public SysHealth selectSysHealthBySthId(Long sthId);

    public List<SysHealth> selectSysHealthList(SysHealth sysHealth);

    public int insertSysHealth(SysHealth sysHealth);

    public int updateSysHealth(SysHealth sysHealth);

    public int deleteSysHealthBySthId(Long sthId);
}
