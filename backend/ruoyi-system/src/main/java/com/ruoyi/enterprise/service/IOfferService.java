package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - Offer 管理服务层
 *
 * <p>依据《业务功能分析》UC-12 步骤9（终面分支）：
 * 终面通过后触发 Offer 发送引擎，生成录用意向书。</p>
 *
 * @author enterprise
 */
public interface IOfferService
{
    /**
     * 触发 Offer（UC-12 步骤9）：生成录用意向书 + 发起审批节点
     */
    public Map<String, Object> triggerOffer(Long userId, Long sessionId, Map<String, Object> body);

    /**
     * Offer 列表（UC-12 步骤9）
     */
    public List<Map<String, Object>> listOffers(Long userId, Integer status, Integer pageNum, Integer pageSize);

    /**
     * Offer 详情（含审批节点，UC-12 步骤9）
     */
    public Map<String, Object> getOfferDetail(Long userId, Long offerId);
}
