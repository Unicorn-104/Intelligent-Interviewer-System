package com.ruoyi.common.enums;

import java.util.List;

/**
 * 岗位投递整体招聘阶段（t_app_record.app_status）。
 *
 * <p>只描述候选人在某个岗位上的整体招聘阶段；某一轮笔试/面试的执行状态与结果由
 * 招聘流程节点实例（t_process_instance_stage）承载，不得写入本状态。</p>
 *
 * <p>状态码为本次重构的固定口径，禁止改动码值与业务含义的对应关系。</p>
 *
 * @author tqy
 */
public enum ApplicationStatus
{
    /** 候选人已成功投递岗位 */
    APPLIED(0, "已投递"),

    /** 正在进行笔试、面试等招聘环节（含待考、补考、改期等全部节点状态） */
    IN_PROGRESS(1, "招聘中"),

    /** 招聘环节通过，等待 HR 发放 Offer */
    PENDING_OFFER(2, "待发Offer"),

    /** Offer 已发送，等待候选人确认（仅 Offer 真正发送成功后才进入） */
    OFFER_PENDING_CONFIRMATION(3, "待确认Offer"),

    /** 候选人接受 Offer，终态 */
    HIRED(4, "已录用"),

    /** 当前岗位招聘流程终止但未成功录用，终态 */
    NOT_HIRED(5, "未录用");

    private final int code;
    private final String label;

    ApplicationStatus(int code, String label)
    {
        this.code = code;
        this.label = label;
    }

    public int getCode()
    {
        return code;
    }

    public String getLabel()
    {
        return label;
    }

    /** 已录用、未录用为终态，普通业务操作不得回退 */
    public boolean isTerminal()
    {
        return this == HIRED || this == NOT_HIRED;
    }

    public static ApplicationStatus fromCode(Integer code)
    {
        if (code == null) return null;
        for (ApplicationStatus status : values())
        {
            if (status.code == code) return status;
        }
        return null;
    }

    public static boolean isTerminalCode(Integer code)
    {
        ApplicationStatus status = fromCode(code);
        return status != null && status.isTerminal();
    }

    /** 终态集合：已录用、未录用 */
    public static final List<ApplicationStatus> TERMINAL = List.of(HIRED, NOT_HIRED);
}
