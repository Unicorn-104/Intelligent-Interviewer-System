package com.ruoyi.system.service;

import java.util.Map;

/**
 * 招聘总览 服务层
 *
 * @author ruoyi
 */
public interface IDashboardService
{
    /**
     * 查询当前用户所属公司的招聘总览数据
     *
     * @param userId 当前登录用户ID
     * @return 总览数据（stats/funnel/todos/timeline）
     */
    public Map<String, Object> getOverview(Long userId);
}
