package com.ruoyi.system.service.impl;

import java.sql.ResultSet;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.domain.app.AppChatMessage;
import com.ruoyi.system.mapper.ImSessionMapper;

/** 单聊已显示消息的单调游标。清空未读角标不等同于查看聊天。 */
@Service
public class ImReadReceiptService
{
    @Autowired private JdbcTemplate jdbc;
    @Autowired private ImSessionMapper sessions;
    private volatile long checkedAt;
    private volatile boolean supported;

    public synchronized boolean available()
    {
        long now = System.currentTimeMillis();
        if (checkedAt == 0 || now - checkedAt >= 10000)
        {
            supported = Boolean.TRUE.equals(jdbc.execute((ConnectionCallback<Boolean>) connection -> {
                try (ResultSet tables = connection.getMetaData().getTables(connection.getCatalog(), null,
                        "t_im_read_cursor", new String[] {"TABLE"}))
                {
                    return tables.next();
                }
            }));
            checkedAt = now;
        }
        return supported;
    }

    private Long peer(Long userId, ImSession session)
    {
        return userId.equals(session.getUserAId()) ? session.getUserBId() : session.getUserAId();
    }

    private long cursor(Long sessionId, Long userId)
    {
        List<Long> rows = jdbc.queryForList("select irc_last_message_id from t_im_read_cursor "
                + "where irc_session_id=? and irc_user_id=?", Long.class, sessionId, userId);
        return rows.isEmpty() ? 0 : rows.get(0);
    }

    public void decorate(Long userId, ImSession session, List<ImMessage> rows)
    {
        if (!available()) return;
        long seen = cursor(session.getSessionId(), peer(userId, session));
        for (ImMessage row : rows)
            row.setDeliveryStatus(userId.equals(row.getSenderId())
                    ? (row.getMessageId() <= seen ? "read" : "delivered") : "received");
    }

    public void decorateCandidate(Long userId, Long sessionId, List<AppChatMessage> rows)
    {
        ImSession session = sessions.selectSessionByIdAndUser(sessionId, userId);
        if (session == null) throw new ServiceException("会话不存在或无权访问");
        if (!available()) return;
        long seen = cursor(sessionId, peer(userId, session));
        for (AppChatMessage row : rows)
            row.setDeliveryStatus(userId.equals(row.getSenderId())
                    ? (row.getMessageId() <= seen ? "read" : "delivered") : "received");
    }

    @Transactional(rollbackFor = Exception.class)
    public Map<String, Object> acknowledge(Long userId, Long sessionId, Long lastMessageId)
    {
        if (sessionId == null || sessionId <= 0 || lastMessageId == null || lastMessageId <= 0)
            throw new ServiceException("会话和消息标识须为正整数");
        // 锁定会话，使游标更新与未读计数更新串行，避免新消息被旧快照清空。
        List<Long> owned = jdbc.queryForList("select ims_id from t_im_session where ims_id=? "
                + "and (ims_user_a_id=? or ims_user_b_id=?) for update", Long.class,
                sessionId, userId, userId);
        if (owned.isEmpty()) throw new ServiceException("会话不存在或无权访问");
        Integer count = jdbc.queryForObject("select count(*) from t_im_message where imsg_id=? "
                + "and imsg_session_id=?", Integer.class, lastMessageId, sessionId);
        if (count == null || count != 1) throw new ServiceException("已读消息不属于当前会话");
        if (!available()) return Map.of("supported", false);
        long seen = Math.max(lastMessageId, cursor(sessionId, userId));
        int changed = jdbc.update("update t_im_read_cursor set irc_last_message_id=?, irc_read_at=current_timestamp "
                + "where irc_session_id=? and irc_user_id=? and irc_last_message_id<?",
                seen, sessionId, userId, seen);
        if (changed == 0 && cursor(sessionId, userId) == 0)
            jdbc.update("insert into t_im_read_cursor (irc_session_id,irc_user_id,irc_last_message_id,irc_read_at) "
                    + "values (?,?,?,current_timestamp)", sessionId, userId, seen);
        Integer unread = jdbc.queryForObject("select count(*) from t_im_message where imsg_session_id=? "
                + "and imsg_sender_id<>? and imsg_id>? and imsg_is_recalled=0", Integer.class,
                sessionId, userId, seen);
        jdbc.update("update t_im_session set ims_unread_a=case when ims_user_a_id=? then ? else ims_unread_a end, "
                + "ims_unread_b=case when ims_user_b_id=? then ? else ims_unread_b end where ims_id=?",
                userId, unread, userId, unread, sessionId);
        return Map.of("supported", true, "lastMessageId", seen);
    }
}
