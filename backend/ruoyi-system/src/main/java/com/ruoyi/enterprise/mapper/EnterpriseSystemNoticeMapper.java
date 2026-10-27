package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import java.time.LocalDateTime;
import org.apache.ibatis.annotations.Param;

public interface EnterpriseSystemNoticeMapper
{
    Long lockRecipient(@Param("userId") Long userId);
    List<Long> recipients(@Param("afterId") Long afterId);
    List<Map<String,Object>> applications(@Param("userId") Long userId,@Param("companyId") Long companyId,@Param("since") LocalDateTime since);
    List<Map<String,Object>> upcoming(@Param("userId") Long userId,@Param("companyId") Long companyId,@Param("now") LocalDateTime now,@Param("until") LocalDateTime until);
    List<Map<String,Object>> reports(@Param("userId") Long userId,@Param("companyId") Long companyId,@Param("since") LocalDateTime since);
    List<Map<String,Object>> interviewStates(@Param("userId") Long userId,@Param("companyId") Long companyId,@Param("since") LocalDateTime since);
    Map<String,Object> ownNotification(@Param("userId") Long userId,@Param("messageId") Long messageId);
    Map<String,Object> applicationTarget(@Param("id") Long id,@Param("companyId") Long companyId);
    Map<String,Object> interviewTarget(@Param("id") Long id,@Param("companyId") Long companyId);
    Map<String,Object> reportTarget(@Param("id") Long id,@Param("companyId") Long companyId);
    int insertNotice(@Param("userId") Long userId,@Param("type") int type,@Param("title") String title,@Param("content") String content,@Param("target") String target);
}
