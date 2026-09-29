package com.ruoyi.system.domain;

import java.util.Date;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.ruoyi.common.core.domain.BaseEntity;

/**
 * IM会话对象 t_im_session
 *
 * @author ruoyi
 */
public class ImSession extends BaseEntity
{
    private static final long serialVersionUID = 1L;

    /** 会话ID */
    private Long sessionId;

    /** HR认证ID */
    private Long userAId;

    /** 候选人认证ID */
    private Long userBId;

    /** 最近消息摘要 */
    private String lastMessage;

    /** 最近消息时间 */
    @JsonFormat(pattern = "yyyy-MM-dd HH:mm:ss")
    private Date lastMessageAt;

    /** A未读数 */
    private Integer unreadA;

    /** B未读数 */
    private Integer unreadB;

    /** 查询结果：对方用户ID（相对当前登录用户） */
    private Long peerId;

    /** 查询结果：对方昵称 */
    private String peerName;

    /** 查询结果：对方头像 */
    private String peerAvatar;

    /** 查询结果：当前用户在该会话的未读数 */
    private Integer unread;

    public Long getSessionId()
    {
        return sessionId;
    }

    public void setSessionId(Long sessionId)
    {
        this.sessionId = sessionId;
    }

    public Long getUserAId()
    {
        return userAId;
    }

    public void setUserAId(Long userAId)
    {
        this.userAId = userAId;
    }

    public Long getUserBId()
    {
        return userBId;
    }

    public void setUserBId(Long userBId)
    {
        this.userBId = userBId;
    }

    public String getLastMessage()
    {
        return lastMessage;
    }

    public void setLastMessage(String lastMessage)
    {
        this.lastMessage = lastMessage;
    }

    public Date getLastMessageAt()
    {
        return lastMessageAt;
    }

    public void setLastMessageAt(Date lastMessageAt)
    {
        this.lastMessageAt = lastMessageAt;
    }

    public Integer getUnreadA()
    {
        return unreadA;
    }

    public void setUnreadA(Integer unreadA)
    {
        this.unreadA = unreadA;
    }

    public Integer getUnreadB()
    {
        return unreadB;
    }

    public void setUnreadB(Integer unreadB)
    {
        this.unreadB = unreadB;
    }

    public Long getPeerId()
    {
        return peerId;
    }

    public void setPeerId(Long peerId)
    {
        this.peerId = peerId;
    }

    public String getPeerName()
    {
        return peerName;
    }

    public void setPeerName(String peerName)
    {
        this.peerName = peerName;
    }

    public String getPeerAvatar()
    {
        return peerAvatar;
    }

    public void setPeerAvatar(String peerAvatar)
    {
        this.peerAvatar = peerAvatar;
    }

    public Integer getUnread()
    {
        return unread;
    }

    public void setUnread(Integer unread)
    {
        this.unread = unread;
    }
}
