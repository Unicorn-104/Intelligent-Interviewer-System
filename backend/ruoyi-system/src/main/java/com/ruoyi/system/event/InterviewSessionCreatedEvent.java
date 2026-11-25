package com.ruoyi.system.event;

/**
 * 纯AI 面试场次创建事件：场次落库后发布，
 * 由监听器在事务提交后异步生成面试题目，避免阻塞建场请求。
 *
 * @author ruoyi
 */
public class InterviewSessionCreatedEvent
{
    private final Long sessionId;

    public InterviewSessionCreatedEvent(Long sessionId)
    {
        this.sessionId = sessionId;
    }

    public Long getSessionId()
    {
        return sessionId;
    }
}
