package com.ruoyi.enterprise.domain;

/**
 * 企业端用户的站内通知偏好开关，默认全部开启。
 */
public class NoticePref
{
    /** 面试提醒：面试即将开始、面试状态更新 */
    private boolean interview = true;

    /** 简历入库：收到新的简历投递 */
    private boolean resume = true;

    /** 候选人消息：候选人新消息提醒（开关已保存，暂未接入发送逻辑） */
    private boolean message = true;

    /** 系统更新：产品更新与维护公告（开关已保存，暂未接入发送逻辑） */
    private boolean system = false;

    public boolean isInterview()
    {
        return interview;
    }

    public void setInterview(boolean interview)
    {
        this.interview = interview;
    }

    public boolean isResume()
    {
        return resume;
    }

    public void setResume(boolean resume)
    {
        this.resume = resume;
    }

    public boolean isMessage()
    {
        return message;
    }

    public void setMessage(boolean message)
    {
        this.message = message;
    }

    public boolean isSystem()
    {
        return system;
    }

    public void setSystem(boolean system)
    {
        this.system = system;
    }
}
