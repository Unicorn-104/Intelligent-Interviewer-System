package com.ruoyi.system.domain.app;

import java.io.Serializable;
import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;

/** C-App 当前用户反馈记录。 */
public class AppFeedback implements Serializable
{
    private static final long serialVersionUID = 1L;

    private Long feedbackId;
    private Integer type;
    private String subject;
    private String description;
    private Integer status;
    private String reply;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date createdAt;

    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date updatedAt;

    public Long getFeedbackId() { return feedbackId; }
    public void setFeedbackId(Long feedbackId) { this.feedbackId = feedbackId; }
    public Integer getType() { return type; }
    public void setType(Integer type) { this.type = type; }
    public String getSubject() { return subject; }
    public void setSubject(String subject) { this.subject = subject; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public Integer getStatus() { return status; }
    public void setStatus(Integer status) { this.status = status; }
    public String getReply() { return reply; }
    public void setReply(String reply) { this.reply = reply; }
    public Date getCreatedAt() { return createdAt; }
    public void setCreatedAt(Date createdAt) { this.createdAt = createdAt; }
    public Date getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Date updatedAt) { this.updatedAt = updatedAt; }

    public String getTypeLabel()
    {
        return switch (type == null ? 0 : type)
        {
            case 1 -> "功能建议";
            case 2 -> "Bug反馈";
            case 3 -> "投诉";
            default -> "其他";
        };
    }

    public String getStatusLabel()
    {
        return switch (status == null ? 0 : status)
        {
            case 1 -> "处理中";
            case 2 -> "已处理";
            default -> "待处理";
        };
    }
}
