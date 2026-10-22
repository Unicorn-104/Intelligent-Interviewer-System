package com.ruoyi.system.mapper.app;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/** All private reads and writes are scoped to the authenticated owner. */
public interface AppAiMapper
{
    int createSession(@Param("id") String id, @Param("userId") Long userId);
    List<Map<String, Object>> sessions(@Param("userId") Long userId, @Param("before") String before);
    Map<String, Object> session(@Param("id") String id, @Param("userId") Long userId);
    Map<String, Object> sessionForUpdate(@Param("id") String id, @Param("userId") Long userId);
    int acquire(@Param("id") String id, @Param("userId") Long userId, @Param("runId") String runId);
    int release(@Param("id") String id, @Param("userId") Long userId, @Param("runId") String runId);
    int title(@Param("id") String id, @Param("userId") Long userId, @Param("title") String title);
    int rename(@Param("id") String id, @Param("userId") Long userId, @Param("title") String title);
    int pin(@Param("id") String id, @Param("userId") Long userId, @Param("pinned") int pinned);
    int deleteSessions(@Param("ids") List<String> ids, @Param("userId") Long userId);
    int deleteSummary(@Param("ids") List<String> ids, @Param("userId") Long userId);
    int deleteEvents(@Param("ids") List<String> ids, @Param("userId") Long userId);
    int deleteMessages(@Param("ids") List<String> ids, @Param("userId") Long userId);
    int deleteRuns(@Param("ids") List<String> ids, @Param("userId") Long userId);
    int createRun(Map<String, Object> run);
    Map<String, Object> run(@Param("id") String id, @Param("userId") Long userId);
    Map<String, Object> requestRun(@Param("sessionId") String sessionId, @Param("requestId") String requestId,
            @Param("userId") Long userId);
    int finish(@Param("id") String id, @Param("userId") Long userId, @Param("status") String status,
            @Param("errorCode") String errorCode, @Param("modelCalls") int modelCalls,
            @Param("toolCalls") int toolCalls, @Param("tokens") int tokens);
    int message(@Param("sessionId") String sessionId, @Param("runId") String runId, @Param("userId") Long userId,
            @Param("role") String role, @Param("content") String content, @Param("cardsJson") String cardsJson);
    List<Map<String, Object>> messages(@Param("sessionId") String sessionId, @Param("userId") Long userId,
            @Param("before") Long before, @Param("limit") int limit);
    int event(@Param("runId") String runId, @Param("userId") Long userId,
            @Param("type") String type, @Param("data") String data);
    List<Map<String, Object>> events(@Param("runId") String runId, @Param("userId") Long userId,
            @Param("after") long after);
}
