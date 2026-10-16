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

    /** Offer 列表（含候选人/岗位信息，按企业隔离） */
    public List<Map<String, Object>> selectOfferList(@Param("status") Integer status,
            @Param("companyId") Long companyId);

    /** Offer 详情（按企业隔离） */
    public Map<String, Object> selectOfferById(@Param("offerId") Long offerId, @Param("companyId") Long companyId);

    /** 审批节点列表 */
    public List<Map<String, Object>> selectApprovals(@Param("offerId") Long offerId);

    /** 当前用户绑定企业ID（数据隔离用） */
    public Long selectCompanyIdByUser(@Param("userId") Long userId);

    /** 岗位基础信息（含企业归属，创建 Offer 校验用） */
    public Map<String, Object> selectPositionBase(@Param("positionId") Long positionId);

    /** 候选人基础信息（创建 Offer 校验用） */
    public Map<String, Object> selectCandidateBase(@Param("candidateId") Long candidateId);

    /** 候选人邮箱（发送录用意向书用） */
    public String selectCandidateEmail(@Param("candidateId") Long candidateId);

    /** 企业名称（邮件抬头用） */
    public String selectCompanyName(@Param("companyId") Long companyId);

    /** 创建 Offer 草稿（状态=4） */
    public int insertOfferDraft(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId,
            @Param("salaryOffer") String salaryOffer, @Param("benefits") String benefits,
            @Param("jobGrade") String jobGrade, @Param("onboardDate") String onboardDate,
            @Param("deadline") String deadline);

    /** 发送后置为已发送（状态=0） */
    public int updateOfferSent(@Param("offerId") Long offerId);

    /** 记录发送录用意向书审批节点 */
    public int insertSendNode(@Param("offerId") Long offerId, @Param("approverId") Long approverId);

    /** 企业候选人选项（创建 Offer 表单用，按投递记录关联本企业岗位） */
    public List<Map<String, Object>> selectCandidateOptions(@Param("companyId") Long companyId);

    /** 企业对外邮箱（t_cmp.cmp_email，发信账号展示用） */
    public String selectCompanyEmail(@Param("companyId") Long companyId);

    /** 当前用户的个人发信配置（含加密授权码，仅 Service 内部使用，禁止直接回显前端） */
    public Map<String, Object> selectMailConfig(@Param("userId") Long userId);

    /** 保存个人发信配置（按用户唯一键 upsert） */
    public int upsertMailConfig(@Param("userId") Long userId, @Param("smtpHost") String smtpHost,
            @Param("smtpPort") Integer smtpPort, @Param("ssl") Integer ssl, @Param("username") String username,
            @Param("passwordEnc") String passwordEnc);
}
