package com.ruoyi.system.service;

import java.util.Map;

/**
 * 企业自助注册服务
 *
 * @author ruoyi
 */
public interface IEnterpriseRegisterService
{
    /**
     * 企业自助注册：企业、账号、绑定与角色在同一事务内写入
     *
     * @param body 注册表单
     */
    public void register(Map<String, Object> body);

    /**
     * 查询当前账号的企业绑定与审核状态
     *
     * @param userId 用户ID
     * @return 状态信息
     */
    public Map<String, Object> accountStatus(Long userId);
}
