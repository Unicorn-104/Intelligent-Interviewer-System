package com.ruoyi.enterprise.service;

import java.util.Map;

/**
 * 笔试与面试发送中心：发送前的上下文聚合查询
 *
 * @author ruoyi
 */
public interface ISendCenterService
{
    /**
     * 查询候选人在指定岗位上的发送上下文（投递状态、阶段与通过情况、笔试前置、在途预约）
     *
     * @param userId 当前登录用户
     * @param candidateId 人才ID
     * @param positionId 岗位ID
     * @return 发送上下文
     */
    public Map<String, Object> getContext(Long userId, Long candidateId, Long positionId);
}
