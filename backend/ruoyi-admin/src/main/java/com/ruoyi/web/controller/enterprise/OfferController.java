package com.ruoyi.web.controller.enterprise;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.IOfferService;

/**
 * 企业端 - Offer 管理
 *
 * <p>依据《业务功能分析》UC-12 步骤9（终面分支）：
 * 终面审核通过后触发 Offer 发送引擎，生成录用意向书
 * （含岗位、薪资区间、入职时间等），通过邮件/短信发送给候选人。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/offer")
public class OfferController extends BaseController
{
    @Autowired
    private IOfferService offerService;

    /**
     * UC-12 步骤9：触发 Offer（终面通过后生成录用意向书并发送）
     */
    @PostMapping("/{sessionId}/trigger")
    public AjaxResult trigger(@PathVariable("sessionId") Long sessionId, @RequestBody(required = false) Map<String, Object> body)
    {
        return success(offerService.triggerOffer(getUserId(), sessionId, body));
    }

    /**
     * UC-12 步骤9：Offer 列表（状态：0-已发送，1-已接受，2-已拒绝，3-已过期，4-草稿，5-审批中，6-已撤回）
     */
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(offerService.listOffers(getUserId(), status, pageNum, pageSize));
    }

    /**
     * UC-12 步骤9：Offer 详情（含审批节点）
     */
    @GetMapping("/{offerId}")
    public AjaxResult detail(@PathVariable("offerId") Long offerId)
    {
        return success(offerService.getOfferDetail(getUserId(), offerId));
    }

    /**
     * Offer 管理页：创建 Offer 草稿（candidateId + positionId + 薪资/职级/福利/入职日期/截止时间）
     */
    @PostMapping("/create")
    public AjaxResult create(@RequestBody Map<String, Object> body)
    {
        return success(offerService.createOffer(getUserId(), body));
    }

    /**
     * Offer 管理页：发送录用意向书与入职指引邮件（草稿转为已发送）
     *
     * <p>body.senderType：company-企业邮箱（默认），personal-个人 SMTP 凭据直发。</p>
     */
    @PostMapping("/{offerId}/send")
    public AjaxResult send(@PathVariable("offerId") Long offerId,
            @RequestBody(required = false) Map<String, Object> body)
    {
        String senderType = body == null || body.get("senderType") == null ? null
                : String.valueOf(body.get("senderType"));
        return success(offerService.sendOffer(getUserId(), offerId, senderType));
    }

    /**
     * Offer 管理页：企业候选人选项（创建表单下拉用，按投递记录关联企业）
     */
    @GetMapping("/candidate-options")
    public AjaxResult candidateOptions()
    {
        return success(offerService.listCandidateOptions(getUserId()));
    }

    /**
     * 个人资料页：邮箱与发信设置回显（企业邮箱 + 个人 SMTP 配置，授权码仅掩码回显）
     */
    @GetMapping("/mail-profile")
    public AjaxResult mailProfile()
    {
        return success(offerService.getMailProfile(getUserId()));
    }

    /**
     * 个人资料页：保存个人 SMTP 发信配置（授权码加密存储，空值或掩码时保留原值）
     */
    @PostMapping("/mail-profile")
    public AjaxResult saveMailProfile(@RequestBody Map<String, Object> body)
    {
        return success(offerService.saveMailProfile(getUserId(), body));
    }
}
