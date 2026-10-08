package com.ruoyi.system.mapper.app;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.app.AppChatMessage;
import com.ruoyi.system.domain.app.AppMessageSummary;

/** C-App 消息中心数据访问。 */
public interface AppMessageMapper
{
    List<AppMessageSummary> selectMessages(@Param("userId") Long userId,
                                           @Param("limit") Integer limit);

    int markSystemMessageRead(@Param("userId") Long userId,
                              @Param("messageId") Long messageId);

    int markHrSessionRead(@Param("userId") Long userId,
                          @Param("sessionId") Long sessionId);

    int markAllSystemMessagesRead(@Param("userId") Long userId);

    int markAllHrSessionsRead(@Param("userId") Long userId);

    List<AppChatMessage> selectHrChatMessages(@Param("userId") Long userId,
                                               @Param("sessionId") Long sessionId,
                                               @Param("limit") Integer limit);

    int insertHrChatMessage(@Param("userId") Long userId,
                            @Param("sessionId") Long sessionId,
                            @Param("content") String content);

    int updateHrSessionAfterCandidateMessage(@Param("userId") Long userId,
                                              @Param("sessionId") Long sessionId,
                                              @Param("content") String content);
}
