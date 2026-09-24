package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * IM消息对象 t_im_message
 *
 * @author ruoyi
 */
public class ImMessage extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 消息ID */
    private Long messageId;

    /** 关联会话ID */
    private Long sessionId;

    /** 发送者认证ID */
    private Long senderId;

    /** 类型：1-文本，2-图片，3-文件，4-表情，5-系统 */
    private Integer type;

    /** 消息内容 */
    private String content;

    /** 附件URL */
    private String attachmentUrl;

    /** 是否撤回 */
    private Integer isRecalled;

    /** 发送时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date sendTime;

    /** 请求参数：聊天对象用户ID（新建会话时使用，不入库） */
    private Long peerId;

    /** 查询结果：是否本人发送（不入库） */
    private Boolean isMine;

    public Long getMessageId()
    {
        return messageId;
    }

    public void setMessageId(Long messageId)
    {
        this.messageId = messageId;
    }

    public Long getSessionId()
    {
        return sessionId;
    }

    public void setSessionId(Long sessionId)
    {
        this.sessionId = sessionId;
    }

    public Long getSenderId()
    {
        return senderId;
    }

    public void setSenderId(Long senderId)
    {
        this.senderId = senderId;
    }

    public Integer getType()
    {
        return type;
    }

    public void setType(Integer type)
    {
        this.type = type;
    }

    public String getContent()
    {
        return content;
    }

    public void setContent(String content)
    {
        this.content = content;
    }

    public String getAttachmentUrl()
    {
        return attachmentUrl;
    }

    public void setAttachmentUrl(String attachmentUrl)
    {
        this.attachmentUrl = attachmentUrl;
    }

    public Integer getIsRecalled()
    {
        return isRecalled;
    }

    public void setIsRecalled(Integer isRecalled)
    {
        this.isRecalled = isRecalled;
    }

    public Date getSendTime()
    {
        return sendTime;
    }

    public void setSendTime(Date sendTime)
    {
        this.sendTime = sendTime;
    }

    public Long getPeerId()
    {
        return peerId;
    }

    public void setPeerId(Long peerId)
    {
        this.peerId = peerId;
    }

    public Boolean getIsMine()
    {
        return isMine;
    }

    public void setIsMine(Boolean isMine)
    {
        this.isMine = isMine;
    }
}
