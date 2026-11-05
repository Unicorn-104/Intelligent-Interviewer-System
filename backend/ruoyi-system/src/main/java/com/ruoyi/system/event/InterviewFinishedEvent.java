package com.ruoyi.system.event;

/**
 * 面试正常结束事件：仅在场次状态成功更新为「已结束」后发布，
 * 由监听器在事务提交后异步触发生成报告，避免阻塞结束响应与事务回滚产生孤儿任务。
 *
 * @author ruoyi
 */
public class InterviewFinishedEvent
{
    private final Long sessionId;

    public InterviewFinishedEvent(Long sessionId)
    {
        this.sessionId = sessionId;
    }

    public Long getSessionId()
    {
        return sessionId;
    }
}
