package com.ruoyi.system.domain.app;

/** 消息分组摘要；历史项的 sourceId 始终为原始通知 ID。 */
public class AppMessageThread extends AppMessageSummary
{
    private static final long serialVersionUID = 1L;
    private String threadType;
    private Long threadId;
    private Integer messageCount;

    public String getThreadType() { return threadType; }
    public void setThreadType(String threadType) { this.threadType = threadType; }
    public Long getThreadId() { return threadId; }
    public void setThreadId(Long threadId) { this.threadId = threadId; }
    public Integer getMessageCount() { return messageCount; }
    public void setMessageCount(Integer messageCount) { this.messageCount = messageCount; }
}
