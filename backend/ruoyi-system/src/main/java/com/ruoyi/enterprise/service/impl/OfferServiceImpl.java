package com.ruoyi.enterprise.service.impl;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.OfferMapper;
import com.ruoyi.enterprise.service.IOfferService;

/**
 * 企业端 - Offer 管理服务实现
 *
 * <p>依据《业务功能分析》UC-12 步骤9（终面分支）：
 * 终面审核通过后自动触发 Offer 发送引擎，生成录用意向书
 * （含岗位、薪资区间、入职时间等），通过邮件/短信发送给候选人。</p>
 *
 * @author enterprise
 */
@Service
public class OfferServiceImpl implements IOfferService
{
    /** Offer 状态（DB 设计文档 §5.5）：0-已发送，5-审批中 */
    private static final int OFR_SENT = 0;

    @Autowired
    private OfferMapper offerMapper;

    @Override
    public Map<String, Object> triggerOffer(Long userId, Long sessionId, Map<String, Object> body)
    {
        Map<String, Object> session = offerMapper.selectSessionBase(sessionId);
        if (session == null)
        {
            throw new ServiceException("面试记录不存在");
        }
        Long candidateId = Long.valueOf(String.valueOf(session.get("candidateId")));
        Long positionId = Long.valueOf(String.valueOf(session.get("positionId")));
        // 幂等：同一场次已存在 Offer 则返回已有记录
        Map<String, Object> existing = offerMapper.selectOfferBySession(candidateId, positionId);
        if (existing != null)
        {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("offerId", existing.get("offerId"));
            result.put("message", "该候选人已存在 Offer，无需重复触发");
            return result;
        }
        String salaryOffer = body == null || body.get("salaryOffer") == null ? null
                : String.valueOf(body.get("salaryOffer"));
        String onboardDate = body == null || body.get("onboardDate") == null ? null
                : String.valueOf(body.get("onboardDate"));
        String deadline = body == null || body.get("deadline") == null ? null
                : String.valueOf(body.get("deadline"));
        // UC-12 步骤9：生成录用意向书（状态=已发送）+ 发起审批节点
        offerMapper.insertOffer(candidateId, positionId, salaryOffer, onboardDate, deadline);
        Long offerId = offerMapper.selectLastOffer(candidateId);
        offerMapper.insertApprovalNode(offerId, "HR 发起", 1, 0);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("offerId", offerId);
        result.put("candidateId", candidateId);
        result.put("positionId", positionId);
        result.put("salaryOffer", salaryOffer);
        result.put("onboardDate", onboardDate);
        result.put("status", OFR_SENT);
        result.put("message", "录用意向书已生成并通过邮件/短信发送（模拟），等待候选人确认");
        return result;
    }

    @Override
    public List<Map<String, Object>> listOffers(Long userId, Integer status, Integer pageNum, Integer pageSize)
    {
        PageUtils.startPage(pageNum, pageSize);
        return offerMapper.selectOfferList(status);
    }

    @Override
    public Map<String, Object> getOfferDetail(Long userId, Long offerId)
    {
        Map<String, Object> offer = offerMapper.selectOfferById(offerId);
        if (offer == null)
        {
            throw new ServiceException("Offer 不存在");
        }
        Map<String, Object> result = new LinkedHashMap<>(offer);
        result.put("approvals", offerMapper.selectApprovals(offerId));
        return result;
    }
}
