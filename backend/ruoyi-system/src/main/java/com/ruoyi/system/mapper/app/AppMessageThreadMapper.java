package com.ruoyi.system.mapper.app;

import java.util.Date;
import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.app.AppMessageThread;

public interface AppMessageThreadMapper
{
    boolean hasRescheduleTable();
    boolean hasInterestTable();

    List<AppMessageThread> selectThreads(@Param("userId") Long userId, @Param("category") String category,
            @Param("beforeTime") Date beforeTime, @Param("beforeId") Long beforeId,
            @Param("beforeType") String beforeType, @Param("limit") int limit,
            @Param("hasReschedule") boolean hasReschedule, @Param("hasInterest") boolean hasInterest);
    List<AppMessageThread> selectUnreadCounts(@Param("userId") Long userId, @Param("hasReschedule") boolean hasReschedule,
            @Param("hasInterest") boolean hasInterest);
    List<AppMessageThread> selectEvents(@Param("userId") Long userId, @Param("threadType") String threadType,
            @Param("threadId") Long threadId, @Param("beforeId") Long beforeId, @Param("limit") int limit,
            @Param("hasReschedule") boolean hasReschedule);
    List<Long> selectReadableIds(@Param("userId") Long userId, @Param("threadType") String threadType,
            @Param("threadId") Long threadId, @Param("ids") List<Long> ids,
            @Param("hasReschedule") boolean hasReschedule);
    int markEventsRead(@Param("userId") Long userId, @Param("ids") List<Long> ids);
}
