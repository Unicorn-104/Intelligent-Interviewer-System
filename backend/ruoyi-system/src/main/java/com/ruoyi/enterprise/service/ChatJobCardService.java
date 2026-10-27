package com.ruoyi.enterprise.service;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.ChatJobCardMapper;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.ImMessageMapper;
import com.ruoyi.system.mapper.ImSessionMapper;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;

@Service
public class ChatJobCardService {
 @Autowired private ChatJobCardMapper cards;
 @Autowired private DashboardMapper companies;
 @Autowired private ImMessageMapper messages;
 @Autowired private ImSessionMapper sessions;
 private final ObjectMapper json=new ObjectMapper();
 private Long company(Long user){Long c=companies.selectCompanyIdByUser(user);if(c==null||c<=0)throw new ServiceException("请先完成企业绑定");return c;}
 public List<Map<String,Object>> jobs(Long user,String keyword,int page){
  if(page<1||page>10000||keyword!=null&&keyword.length()>100)throw new ServiceException("岗位查询参数无效");
  return cards.jobs(company(user),keyword==null?null:keyword.trim(),(page-1)*20);
 }
 private void positive(Long id){if(id==null||id<=0)throw new ServiceException("岗位与聊天对象标识须为正整数");}
 @Transactional(rollbackFor=Exception.class)
 public Map<String,Object> send(Long user,Long sessionId,Long peerId,Long positionId,String requestId){
  positive(user);positive(positionId);
  if(requestId==null||!requestId.matches("[0-9a-f]{24}"))throw new ServiceException("发送请求标识无效");
  if(cards.lockSender(user)==null)throw new ServiceException("当前账号不可用");
  Long company=company(user);
  ImSession session=null;
  if(sessionId!=null){positive(sessionId);session=sessions.selectSessionByIdAndUser(sessionId,user);if(session==null)throw new ServiceException("会话不存在或无权访问");
   Long actual=user.equals(session.getUserAId())?session.getUserBId():session.getUserAId();
   if(peerId!=null&&!peerId.equals(actual))throw new ServiceException("会话与求职者不匹配");peerId=actual;
  }
  positive(peerId);if(peerId.equals(user)||cards.candidateUser(peerId)==null)throw new ServiceException("聊天对象不是有效求职者");
  var old=cards.existing(user,requestId);
  if(old!=null){
   try{var content=json.readTree(String.valueOf(old.get("content")));if(content.path("positionId").asLong()!=positionId||!Objects.equals(((Number)old.get("peerId")).longValue(),peerId)||sessionId!=null&&!Objects.equals(((Number)old.get("sessionId")).longValue(),sessionId))throw new ServiceException("同一发送标识不能用于不同岗位或会话");}
   catch(com.fasterxml.jackson.core.JsonProcessingException ex){throw new ServiceException("原发送结果无法核对");}
   return result(old,requestId);
  }
  var job=cards.job(company,positionId);if(job==null)throw new ServiceException("岗位已停招、不存在或不属于当前企业");
  if(session==null){session=sessions.selectSessionByUsers(user,peerId);if(session==null){session=new ImSession();session.setUserAId(user);session.setUserBId(peerId);if(sessions.insertSession(session)!=1)throw new ServiceException("聊天会话创建失败");}}
  if(!user.equals(session.getUserAId()))throw new ServiceException("当前会话不符合招聘者与求职者身份，请刷新会话");
  var content=new LinkedHashMap<String,Object>(job);content.put("kind","job_card");content.put("version",1);content.put("requestId",requestId);
  var message=new ImMessage();message.setSessionId(session.getSessionId());message.setSenderId(user);message.setType(6);
  try{message.setContent(json.writeValueAsString(content));}catch(Exception ex){throw new ServiceException("岗位卡片生成失败");}
  if(messages.insertMessage(message)!=1)throw new ServiceException("岗位卡片保存失败");
  String summary="[岗位] "+job.get("title");if(summary.length()>200)summary=summary.substring(0,200);
  if(sessions.updateSessionOnSend(session.getSessionId(),summary,peerId)!=1)throw new ServiceException("岗位会话摘要保存失败");
  return Map.of("messageId",message.getMessageId(),"sessionId",session.getSessionId(),"requestId",requestId);
 }
 private Map<String,Object> result(Map<String,Object> row,String request){return Map.of("messageId",row.get("messageId"),"sessionId",row.get("sessionId"),"requestId",request);}
}
