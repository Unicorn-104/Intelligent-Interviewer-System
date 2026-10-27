package com.ruoyi.system.mapper.agent;

import java.util.List;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.agent.AgentResumeAttachment;

/** 求职者简历附件数据访问层。 */
public interface AgentResumeAttachmentMapper
{
    int countOwnedResume(@Param("userId") Long userId, @Param("resumeId") Long resumeId);
    int countActive(@Param("userId") Long userId, @Param("resumeId") Long resumeId);
    List<AgentResumeAttachment> selectList(@Param("userId") Long userId, @Param("resumeId") Long resumeId);
    AgentResumeAttachment selectById(@Param("userId") Long userId, @Param("resumeId") Long resumeId,
            @Param("attachmentId") Long attachmentId);
    @Options(useGeneratedKeys = true, keyProperty = "id", keyColumn = "rsa_id")
    int insert(AgentResumeAttachment attachment);
    int softDelete(@Param("userId") Long userId, @Param("resumeId") Long resumeId,
            @Param("attachmentId") Long attachmentId);
}