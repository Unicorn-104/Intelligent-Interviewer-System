package com.ruoyi.enterprise.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.mapper.ImMessageMapper;
import com.ruoyi.system.mapper.ImSessionMapper;

/**
 * 笔试通知卡片：在招聘者与候选人的 IM 会话中写入 type=5 的邀请卡片。
 *
 * 卡片正文与候选人 PC 端一致，使用「【笔试邀请·试卷名】...进入考试：链接」文本，
 * 不依赖客户端私有 JSON，旧版消息中心仍能按普通文本展示可点击链接。
 */
@Service
public class ExamInvitationCardService
{
    private static final int MAX_CONTENT_LENGTH = 1000;

    @Autowired
    private ImSessionMapper sessions;

    @Autowired
    private ImMessageMapper messages;

    @Transactional(rollbackFor = Exception.class)
    public void sendCard(Long recruiterId, Long candidateId, String content, String summary)
    {
        if (recruiterId == null || candidateId == null || recruiterId <= 0 || candidateId <= 0)
        {
            throw new ServiceException("笔试邀请会话账号无效");
        }
        if (recruiterId.equals(candidateId))
        {
            throw new ServiceException("笔试邀请会话双方身份异常");
        }
        String text = StringUtils.nvl(content, "").trim();
        if (text.isEmpty() || text.length() > MAX_CONTENT_LENGTH)
        {
            throw new ServiceException("笔试邀请卡片内容无效");
        }
        String brief = StringUtils.nvl(summary, "【笔试邀请】").trim();
        if (brief.isEmpty())
        {
            brief = "【笔试邀请】";
        }
        if (brief.length() > 200)
        {
            brief = brief.substring(0, 200);
        }

        ImSession session = sessions.selectSessionByUsers(recruiterId, candidateId);
        if (session == null)
        {
            session = new ImSession();
            // 与既有 HR 会话契约一致：企业账号为 userA，候选人账号为 userB。
            session.setUserAId(recruiterId);
            session.setUserBId(candidateId);
            if (sessions.insertSession(session) != 1 || session.getSessionId() == null)
            {
                throw new ServiceException("笔试邀请会话保存失败");
            }
        }

        ImMessage message = new ImMessage();
        message.setSessionId(session.getSessionId());
        message.setSenderId(recruiterId);
        message.setType(5);
        message.setContent(text);
        if (messages.insertMessage(message) != 1)
        {
            throw new ServiceException("笔试邀请卡片保存失败");
        }
        if (sessions.updateSessionOnSend(session.getSessionId(), brief, candidateId) != 1)
        {
            throw new ServiceException("笔试邀请会话更新失败");
        }
    }
}
