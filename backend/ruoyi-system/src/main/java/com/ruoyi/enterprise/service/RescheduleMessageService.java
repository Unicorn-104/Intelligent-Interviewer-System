package com.ruoyi.enterprise.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.RescheduleRequestMapper;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.mapper.ImMessageMapper;
import com.ruoyi.system.mapper.ImSessionMapper;

/** 仅由经过权限校验的改期事务调用；消息失败必须回滚业务变更。 */
@Service
@Transactional(propagation = Propagation.MANDATORY, rollbackFor = Exception.class)
public class RescheduleMessageService
{
    @Autowired private RescheduleRequestMapper requests;
    @Autowired private ImSessionMapper sessions;
    @Autowired private ImMessageMapper messages;
    private final ObjectMapper json = new ObjectMapper();

    public void changed(Long recruiterId, Map<String, Object> after)
    {
        Map<String, Object> card = card(after, "changed");
        card.put("originalStartTime", after.get("originalStartTime"));
        card.put("originalEndTime", after.get("originalEndTime"));
        card.put("newStartTime", after.get("startTime"));
        card.put("newEndTime", after.get("endTime"));
        Long candidate = id(after.get("candidateUserId"));
        chat(recruiterId, candidate, recruiterId, card, "[改期通知] 面试时间已变更");
        notification(candidate, "面试改期通知", card,
                "/candidate/interview/appointments/" + after.get("appointmentId"));
    }

    public void submitted(Map<String, Object> request)
    {
        Map<String, Object> card = card(request, "pending");
        Long candidate = id(request.get("requesterId"));
        List<Long> recipients = requests.selectCompanyUserIds(id(request.get("companyId")))
                .stream().filter(user -> !candidate.equals(user)).distinct().toList();
        if (recipients.isEmpty()) throw new ServiceException("企业暂无可接收改期申请的账号，请联系招聘者");
        for (Long recruiter : recipients)
        {
            chat(recruiter, candidate, candidate, card, "[改期申请] 等待处理");
            notification(recruiter, "收到面试改期申请", card,
                    "/enterprise/interview/reschedule-requests/" + request.get("requestId"));
        }
    }

    public void reviewed(Long reviewerId, Map<String, Object> request)
    {
        // 兼容通知功能上线前提交的申请；审批结果卡片仍在本事务内创建。
        messages.updateRescheduleCards(id(request.get("requestId")),
                String.valueOf(request.get("status")), (request.get("reviewNote") == null ? "" : String.valueOf(request.get("reviewNote"))));
        Map<String, Object> card = card(request, String.valueOf(request.get("status")));
        card.put("reviewNote", request.get("reviewNote"));
        String title = "approved".equals(request.get("status")) ? "改期申请已同意" : "改期申请已拒绝";
        Long candidate = id(request.get("requesterId"));
        // 同一企业所有收件会话得到结果，不能留下可重复操作的旧申请卡。
        List<Long> recipients = new java.util.ArrayList<>(requests.selectCompanyUserIds(id(request.get("companyId"))));
        if (!recipients.contains(reviewerId)) recipients.add(reviewerId);
        for (Long recruiter : recipients.stream().filter(user -> !candidate.equals(user)).distinct().toList())
            chat(recruiter, candidate, recruiter, card, "[改期结果] " + title);
        notification(candidate, title, card,
                "/candidate/interview/reschedule-requests/" + request.get("requestId"));
    }

    private Map<String, Object> card(Map<String, Object> row, String status)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("kind", "interview_reschedule");
        result.put("version", 1);
        for (String key : List.of("requestId", "appointmentId", "candidateName", "originalStartTime",
                "originalEndTime", "newStartTime", "newEndTime", "reason")) result.put(key, row.get(key));
        result.put("positionName", row.getOrDefault("positionName", row.get("positionTitle")));
        result.put("status", status);
        return result;
    }

    private void notification(Long receiver, String title, Map<String, Object> card, String target)
    {
        String text = "申请人：" + card.get("candidateName") + "\n岗位：" + card.get("positionName") + "\n原时间：" + card.get("originalStartTime")
                + " ~ " + card.get("originalEndTime") + "\n申请/新时间：" + card.get("newStartTime")
                + " ~ " + card.get("newEndTime");
        if (card.get("reason") != null) text += "\n原因：" + card.get("reason");
        if (card.get("reviewNote") != null) text += "\n审批说明：" + card.get("reviewNote");
        if (requests.insertNotification(receiver, title, text, target) != 1)
            throw new ServiceException("改期通知保存失败，请核对后重试");
    }

    private void chat(Long recruiter, Long candidate, Long sender, Map<String, Object> card, String summary)
    {
        if (recruiter.equals(candidate)) throw new ServiceException("改期会话双方身份异常");
        ImSession session = sessions.selectSessionByUsers(recruiter, candidate);
        if (session == null)
        {
            session = new ImSession();
            session.setUserAId(recruiter); // 与 C-APP 既有 HR 会话契约一致。
            session.setUserBId(candidate);
            if (sessions.insertSession(session) != 1) throw new ServiceException("改期会话保存失败");
        }
        ImMessage message = new ImMessage();
        message.setSessionId(session.getSessionId());
        message.setSenderId(sender);
        message.setType(5);
        try { message.setContent(json.writeValueAsString(card)); }
        catch (JsonProcessingException ex) { throw new ServiceException("改期卡片生成失败"); }
        if (messages.insertMessage(message) != 1) throw new ServiceException("改期卡片保存失败");
        Long receiver = sender.equals(recruiter) ? candidate : recruiter;
        if (sessions.updateSessionOnSend(session.getSessionId(), summary, receiver) != 1)
            throw new ServiceException("改期会话更新失败");
    }

    private Long id(Object raw)
    {
        try { long value = Long.parseLong(String.valueOf(raw)); if (value > 0) return value; }
        catch (RuntimeException ignored) { }
        throw new ServiceException("改期消息关联账号无效");
    }
}
