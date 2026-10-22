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
}
