package com.ruoyi.system.mapper.app;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

public interface AppAiMemoryMapper
{
    int initialize(@Param("userId") Long userId);
    Map<String, Object> state(@Param("userId") Long userId);
    Map<String, Object> lock(@Param("userId") Long userId);
    List<Map<String, Object>> items(@Param("userId") Long userId);
    int save(@Param("userId") Long userId, @Param("key") String key, @Param("value") String value);
    int forget(@Param("userId") Long userId, @Param("key") String key);
    int change(@Param("userId") Long userId, @Param("enabled") int enabled, @Param("fence") long fence);
    int active(@Param("userId") Long userId);
    long latest(@Param("userId") Long userId);
    int clearSummaries(@Param("userId") Long userId);
    Map<String, Object> summary(@Param("userId") Long userId, @Param("sessionId") String sessionId);
    List<Map<String, Object>> summaryMessages(@Param("userId") Long userId, @Param("sessionId") String sessionId,
            @Param("after") long after, @Param("before") long before);
    int saveSummary(@Param("userId") Long userId, @Param("sessionId") String sessionId,
            @Param("content") String content, @Param("through") long through, @Param("revision") long revision);
    int enqueueExtraction(@Param("runId") String runId, @Param("userId") Long userId, @Param("sessionId") String sessionId);
    Map<String, Object> nextExtractionJob();
    int claimExtractionJob(@Param("runId") String runId);
    Map<String, Object> extractionSource(@Param("runId") String runId, @Param("userId") Long userId);
    List<Map<String, Object>> activeItems(@Param("userId") Long userId, @Param("limit") int limit);
    Map<String, Object> activeItem(@Param("id") String id, @Param("userId") Long userId);
    List<Map<String, Object>> activeItemsByIds(@Param("ids") List<String> ids, @Param("userId") Long userId);
    int insertItem(Map<String, Object> item);
    int addEvidence(Map<String, Object> evidence);
    Map<String, Object> findDuplicate(@Param("userId") Long userId, @Param("contentHash") String contentHash);
    int supersede(@Param("id") String id, @Param("userId") Long userId, @Param("replacementId") String replacementId);
    int updateItem(@Param("id") String id, @Param("userId") Long userId,
            @Param("content") String content, @Param("contentHash") String contentHash);
    int deleteItem(@Param("id") String id, @Param("userId") Long userId);
    int enqueueVector(@Param("id") String id, @Param("userId") Long userId,
            @Param("revision") long revision, @Param("operation") String operation);
    Map<String, Object> nextVectorJob();
    int claimVectorJob(@Param("id") long id);
    Map<String, Object> vectorItem(@Param("id") String id, @Param("userId") Long userId);
    int completeExtractionJob(@Param("runId") String runId);
    int retryExtractionJob(@Param("runId") String runId, @Param("errorType") String errorType, @Param("delaySeconds") int delaySeconds);
    int failExtractionJob(@Param("runId") String runId, @Param("errorType") String errorType);
    int completeVectorJob(@Param("id") long id);
    int retryVectorJob(@Param("id") long id, @Param("errorType") String errorType, @Param("delaySeconds") int delaySeconds);
    int failVectorJob(@Param("id") long id, @Param("errorType") String errorType);
}
