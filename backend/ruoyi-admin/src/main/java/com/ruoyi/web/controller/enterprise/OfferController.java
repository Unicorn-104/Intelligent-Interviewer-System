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
}
