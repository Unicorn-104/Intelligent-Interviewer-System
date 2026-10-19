package com.ruoyi.enterprise.service.impl;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.enterprise.mapper.OfferMapper;
import com.ruoyi.enterprise.service.IOfferService;
import com.ruoyi.enterprise.util.MailCredentialCipher;
import com.ruoyi.system.service.EmailService;

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

    /** Offer 状态：4-草稿 */
    private static final int OFR_DRAFT = 4;

    /** 发信账号类型：个人 SMTP 直发（其余一律按企业邮箱处理） */
    private static final String SENDER_PERSONAL = "personal";

    /** 授权码掩码：前端回显与"保留原值"判断共用 */
    private static final String PASSWORD_MASK = "********";

    @Autowired
    private OfferMapper offerMapper;

    @Autowired
    private EmailService emailService;

    @Autowired
    private MailCredentialCipher mailCredentialCipher;

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
        // 先解析企业ID，再开启分页，避免 PageHelper 拦截到非分页查询
        Long companyId = resolveCompanyId(userId);
        PageUtils.startPage(pageNum, pageSize);
        return offerMapper.selectOfferList(status, companyId);
    }

    @Override
    public Map<String, Object> getOfferDetail(Long userId, Long offerId)
    {
        Map<String, Object> offer = offerMapper.selectOfferById(offerId, resolveCompanyId(userId));
        if (offer == null)
        {
            throw new ServiceException("Offer 不存在或无权访问");
        }
        Map<String, Object> result = new LinkedHashMap<>(offer);
        result.put("approvals", offerMapper.selectApprovals(offerId));
        return result;
    }

    @Override
    public Map<String, Object> createOffer(Long userId, Map<String, Object> body)
    {
        Long companyId = resolveCompanyId(userId);
        Long candidateId = toLong(body == null ? null : body.get("candidateId"));
        Long positionId = toLong(body == null ? null : body.get("positionId"));
        if (candidateId == null || positionId == null)
        {
            throw new ServiceException("请选择候选人与岗位");
        }
        Map<String, Object> position = offerMapper.selectPositionBase(positionId);
        if (position == null || !companyId.equals(toLong(position.get("companyId"))))
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        Map<String, Object> candidate = offerMapper.selectCandidateBase(candidateId);
        if (candidate == null)
        {
            throw new ServiceException("候选人不存在");
        }
        String salaryOffer = str(body.get("salaryOffer"));
        if (StringUtils.isEmpty(salaryOffer))
        {
            throw new ServiceException("请填写薪资报价");
        }
        offerMapper.insertOfferDraft(candidateId, positionId, salaryOffer, blankToNull(str(body.get("benefits"))),
                blankToNull(str(body.get("jobGrade"))), blankToNull(str(body.get("onboardDate"))),
                blankToNull(str(body.get("deadline"))));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("offerId", offerMapper.selectLastOffer(candidateId));
        result.put("candidateName", candidate.get("candidateName"));
        result.put("positionTitle", position.get("positionTitle"));
        result.put("status", OFR_DRAFT);
        result.put("message", "Offer 草稿已创建，可在列表中发送录用意向书");
        return result;
    }

    @Override
    public Map<String, Object> sendOffer(Long userId, Long offerId, String senderType)
    {
        Map<String, Object> offer = offerMapper.selectOfferById(offerId, resolveCompanyId(userId));
        if (offer == null)
        {
            throw new ServiceException("Offer 不存在或无权访问");
        }
        if (toInt(offer.get("status")) != OFR_DRAFT)
        {
            throw new ServiceException("仅草稿状态的 Offer 可发送");
        }
        String email = offerMapper.selectCandidateEmail(toLong(offer.get("candidateId")));
        if (StringUtils.isEmpty(email))
        {
            throw new ServiceException("候选人未配置邮箱，无法发送录用意向书");
        }
        String candidateName = str(offer.get("candidateName"));
        String positionTitle = str(offer.get("positionTitle"));
        String companyName = offerMapper.selectCompanyName(resolveCompanyId(userId));
        String intentSubject = "【录用意向书】" + companyName + " - " + positionTitle + "（" + candidateName + "）";
        StringBuilder intent = new StringBuilder();
        intent.append(candidateName).append(" 您好：\n\n");
        intent.append("恭喜您通过 ").append(companyName).append(" 的面试，我们诚挚地邀请您加入！\n\n");
        intent.append("录用信息如下：\n");
        intent.append("应聘岗位：").append(positionTitle).append('\n');
        intent.append("薪资报价：").append(str(offer.get("salaryOffer"))).append('\n');
        if (StringUtils.isNotEmpty(str(offer.get("jobGrade"))))
        {
            intent.append("职级：").append(offer.get("jobGrade")).append('\n');
        }
        if (StringUtils.isNotEmpty(str(offer.get("benefits"))))
        {
            intent.append("福利说明：").append(offer.get("benefits")).append('\n');
        }
        intent.append("预计入职日期：").append(offer.get("onboardDate")).append('\n');
        intent.append("回复截止时间：").append(offer.get("deadline")).append("\n\n");
        intent.append("请您在截止时间前回复确认，期待与您共事！\n");
        String guideSubject = "【入职指引】" + companyName + " 欢迎加入（" + candidateName + "）";
        StringBuilder guide = new StringBuilder();
        guide.append(candidateName).append(" 您好：\n\n");
        guide.append("欢迎加入 ").append(companyName).append("！入职当天请注意以下事项：\n\n");
        guide.append("1. 报到时间：").append(offer.get("onboardDate")).append(" 上午 9:30 前\n");
        guide.append("2. 携带材料：身份证、学历学位证书、离职证明、银行卡、体检报告\n");
        guide.append("3. 报到地点：以 HR 现场通知为准\n");
        guide.append("4. 如有疑问，请邮件回复本指引或直接联系您的对接 HR\n");
        boolean personal = SENDER_PERSONAL.equals(senderType);
        String senderAccount;
        boolean intentSent;
        boolean guideSent;
        if (personal)
        {
            Map<String, Object> config = offerMapper.selectMailConfig(userId);
            if (config == null)
            {
                throw new ServiceException("尚未配置个人邮箱 SMTP，请先在「个人资料 → 邮箱与发信设置」中完成配置");
            }
            senderAccount = str(config.get("username"));
            String password = mailCredentialCipher.decrypt(str(config.get("passwordEnc")));
            intentSent = emailService.sendMailWith(str(config.get("smtpHost")), toInt(config.get("smtpPort")),
                    toInt(config.get("ssl")) == 1, senderAccount, password, email, intentSubject, intent.toString());
            guideSent = emailService.sendMailWith(str(config.get("smtpHost")), toInt(config.get("smtpPort")),
                    toInt(config.get("ssl")) == 1, senderAccount, password, email, guideSubject, guide.toString());
        }
        else
        {
            senderAccount = offerMapper.selectCompanyEmail(resolveCompanyId(userId));
            intentSent = emailService.sendSimpleMail(email, intentSubject, intent.toString());
            guideSent = emailService.sendSimpleMail(email, guideSubject, guide.toString());
        }
        offerMapper.updateOfferSent(offerId);
        offerMapper.insertSendNode(offerId, userId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("offerId", offerId);
        result.put("email", email);
        result.put("senderType", personal ? SENDER_PERSONAL : "company");
        result.put("senderAccount", senderAccount);
        result.put("intentMailSent", intentSent);
        result.put("guideMailSent", guideSent);
        result.put("status", OFR_SENT);
        result.put("message", intentSent && guideSent
                ? "录用意向书与入职指引已由「" + senderAccount + "」发送至 " + email
                : "Offer 已标记为已发送，但邮件投递失败（" + (personal ? "个人 SMTP 认证或网络异常" : "企业 SMTP 未配置有效凭据") + "）");
        return result;
    }

    @Override
    public Map<String, Object> getMailProfile(Long userId)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("companyEmail", offerMapper.selectCompanyEmail(resolveCompanyId(userId)));
        Map<String, Object> config = offerMapper.selectMailConfig(userId);
        boolean configured = config != null;
        result.put("configured", configured);
        result.put("smtpHost", configured ? config.get("smtpHost") : null);
        result.put("smtpPort", configured ? config.get("smtpPort") : null);
        result.put("ssl", configured ? config.get("ssl") : null);
        result.put("username", configured ? config.get("username") : null);
        result.put("passwordMask", configured ? PASSWORD_MASK : "");
        return result;
    }

    @Override
    public Map<String, Object> saveMailProfile(Long userId, Map<String, Object> body)
    {
        String smtpHost = blankToNull(str(body == null ? null : body.get("smtpHost")));
        String username = blankToNull(str(body == null ? null : body.get("username")));
        Integer smtpPort = body == null ? null : toInt(body.get("smtpPort"));
        if (smtpHost == null || username == null)
        {
            throw new ServiceException("请填写 SMTP 服务器与认证账号");
        }
        if (smtpPort == null || smtpPort <= 0 || smtpPort > 65535)
        {
            throw new ServiceException("请填写有效的 SMTP 端口（1-65535）");
        }
        Integer ssl = body == null ? null : toInt(body.get("ssl"));
        int sslFlag = ssl != null && ssl == 0 ? 0 : 1;
        String password = str(body == null ? null : body.get("password"));
        Map<String, Object> existing = offerMapper.selectMailConfig(userId);
        String passwordEnc;
        if (StringUtils.isEmpty(password) || PASSWORD_MASK.equals(password))
        {
            if (existing == null)
            {
                throw new ServiceException("请填写邮箱授权码");
            }
            passwordEnc = str(existing.get("passwordEnc"));
        }
        else
        {
            passwordEnc = mailCredentialCipher.encrypt(password);
        }
        offerMapper.upsertMailConfig(userId, smtpHost, smtpPort, sslFlag, username, passwordEnc);
        Map<String, Object> result = getMailProfile(userId);
        result.put("message", "个人发信配置已保存（授权码已加密存储）");
        return result;
    }

    @Override
    public List<Map<String, Object>> listCandidateOptions(Long userId)
    {
        return offerMapper.selectCandidateOptions(resolveCompanyId(userId));
    }

    /** 解析当前用户绑定企业ID（未绑定回落到默认企业 1，与项目其他企业端模块口径一致） */
    private Long resolveCompanyId(Long userId)
    {
        Long companyId = offerMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }

    private String str(Object value)
    {
        return value == null ? null : String.valueOf(value);
    }

    private String blankToNull(String value)
    {
        return StringUtils.isEmpty(value) ? null : value;
    }

    private Long toLong(Object value)
    {
        if (value == null || StringUtils.isEmpty(String.valueOf(value)))
        {
            return null;
        }
        return Long.valueOf(String.valueOf(value));
    }

    private int toInt(Object value)
    {
        return value == null ? -1 : Integer.parseInt(String.valueOf(value));
    }
}
