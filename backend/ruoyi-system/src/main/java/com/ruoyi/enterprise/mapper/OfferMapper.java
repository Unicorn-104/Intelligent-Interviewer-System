package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - Offer 管理数据层
 *
 * <p>依据《业务功能分析》UC-12 步骤9：
 * 录用意向书 t_off_offer（0-已发送，1-已接受，2-已拒绝，3-已过期，
 * 4-草稿，5-审批中，6-已撤回）、审批节点 t_offer_approval。</p>
 *
 * @author enterprise
 */
public interface OfferMapper
{
    /** 会话基础信息（触发 Offer 用） */
    public Map<String, Object> selectSessionBase(@Param("sessionId") Long sessionId);

    /** 候选人已有 Offer 查询（幂等校验） */
    public Map<String, Object> selectOfferBySession(@Param("candidateId") Long candidateId,
            @Param("positionId") Long positionId);

    /** 创建录用意向书 */
    public int insertOffer(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId,
            @Param("salaryOffer") String salaryOffer, @Param("onboardDate") String onboardDate,
            @Param("deadline") String deadline);

    /** 查询刚创建的 Offer ID */
    public Long selectLastOffer(@Param("candidateId") Long candidateId);

    /** 创建审批节点 */
    public int insertApprovalNode(@Param("offerId") Long offerId, @Param("nodeName") String nodeName,
            @Param("nodeOrder") Integer nodeOrder, @Param("status") Integer status);

    /** Offer 列表（含候选人/岗位信息） */
    public List<Map<String, Object>> selectOfferList(@Param("status") Integer status);

    /** Offer 详情 */
    public Map<String, Object> selectOfferById(@Param("offerId") Long offerId);

    /** 审批节点列表 */
    public List<Map<String, Object>> selectApprovals(@Param("offerId") Long offerId);
}
