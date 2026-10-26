package com.ruoyi.system.service.agent;

import java.util.List;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.system.domain.agent.AgentResumeAttachment;
import com.ruoyi.system.domain.app.AppResumeAttachmentDocument;

/** 求职者简历附加文件服务。 */
public interface IAgentResumeAttachmentService
{
    List<AgentResumeAttachment> list(Long userId, Long resumeId);
    List<AgentResumeAttachment> add(Long userId, Long resumeId, MultipartFile[] files) throws Exception;
    AppResumeAttachmentDocument file(Long userId, Long resumeId, Long attachmentId);
    List<AgentResumeAttachment> delete(Long userId, Long resumeId, Long attachmentId);
}