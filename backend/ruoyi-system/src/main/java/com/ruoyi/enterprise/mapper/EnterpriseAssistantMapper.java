package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/** Only status=7 sessions bearing an enterprise/company marker belong to this assistant. */
public interface EnterpriseAssistantMapper
{
    int createSession(Map<String,Object> row);
    int insertMessage(Map<String,Object> row);
    Map<String,Object> session(@Param("id") Long id,@Param("userId") Long userId,@Param("companyId") Long companyId);
    Long lockSession(@Param("id") Long id,@Param("userId") Long userId);
    List<Map<String,Object>> sessions(@Param("userId") Long userId,@Param("companyId") Long companyId,@Param("before") Long before);
    List<Map<String,Object>> messages(@Param("sessionId") Long sessionId,@Param("before") Long before,@Param("limit") int limit);
    Map<String,Object> request(@Param("sessionId") Long sessionId,@Param("intent") String intent);
    Map<String,Object> run(@Param("id") Long id,@Param("userId") Long userId,@Param("companyId") Long companyId);
    int expire(@Param("sessionId") Long sessionId);
    int active(@Param("sessionId") Long sessionId);
    int updateRun(@Param("id") Long id,@Param("content") String content,@Param("state") String state);
    int touch(@Param("id") Long id);
    int deleteMessages(@Param("id") Long id);
    int deleteSession(@Param("id") Long id,@Param("userId") Long userId);
    List<Map<String,Object>> jobs(@Param("companyId") Long companyId,@Param("keyword") String keyword);
    Map<String,Object> job(@Param("companyId") Long companyId,@Param("id") Long id);
}
