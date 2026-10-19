package com.ruoyi.system.domain;

import com.ruoyi.common.core.domain.BaseEntity;
import jakarta.validation.constraints.NotBlank;

/**
 * 广告位管理对象 t_ad_slot
 *
 * @author TQY
 */
public class AdSlot extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 广告位编码 */
    private String slotCode;

    /** 广告位名称 */
    @NotBlank(message = "广告位名称不能为空")
    private String slotName;

    /** 广告位类型（splash开屏 popup弹窗 banner轮播 feed信息流） */
    private String slotType;

    /** 投放端（hrHR端 candidate候选人端 all全部） */
    private String target;

    /** 展示规则描述 */
    private String ruleDesc;

    /** 展示规则（JSON） */
    private String rule;

    /** 状态（0启用 1停用） */
    private String status;

    /** 当前广告数（关联查询用） */
    private Integer adCount;

    public String getSlotCode() { return slotCode; }
    public void setSlotCode(String slotCode) { this.slotCode = slotCode; }

    public String getSlotName() { return slotName; }
    public void setSlotName(String slotName) { this.slotName = slotName; }

    public String getSlotType() { return slotType; }
    public void setSlotType(String slotType) { this.slotType = slotType; }

    public String getTarget() { return target; }
    public void setTarget(String target) { this.target = target; }

    public String getRuleDesc() { return ruleDesc; }
    public void setRuleDesc(String ruleDesc) { this.ruleDesc = ruleDesc; }

    public String getRule() { return rule; }
    public void setRule(String rule) { this.rule = rule; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Integer getAdCount() { return adCount; }
    public void setAdCount(Integer adCount) { this.adCount = adCount; }
}
