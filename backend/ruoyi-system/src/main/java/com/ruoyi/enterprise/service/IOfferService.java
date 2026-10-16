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

    /**
     * 创建 Offer 草稿（企业端 Offer 管理页）
     */
    public Map<String, Object> createOffer(Long userId, Map<String, Object> body);

    /**
     * 发送录用意向书与入职指引邮件（发送后草稿转为已发送）
     *
     * @param senderType 发信账号类型：company-企业邮箱（全局 SMTP），personal-个人 SMTP 凭据直发
     */
    public Map<String, Object> sendOffer(Long userId, Long offerId, String senderType);

    /**
     * 企业候选人选项（创建 Offer 表单用）
     */
    public List<Map<String, Object>> listCandidateOptions(Long userId);

    /**
     * 邮箱与发信设置回显（企业邮箱 + 个人 SMTP 配置，授权码仅掩码回显）
     */
    public Map<String, Object> getMailProfile(Long userId);

    /**
     * 保存个人 SMTP 发信配置（授权码 AES 加密存储；密码为空或为掩码时保留原值）
     */
    public Map<String, Object> saveMailProfile(Long userId, Map<String, Object> body);
}
