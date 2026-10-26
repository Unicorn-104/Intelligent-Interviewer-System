package com.ruoyi.system.service.impl.agent;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.agent.AgentResumeAttachment;
import com.ruoyi.system.domain.app.AppResumeAttachmentDocument;
import com.ruoyi.system.mapper.agent.AgentResumeAttachmentMapper;
import com.ruoyi.system.service.agent.IAgentResumeAttachmentService;
import com.ruoyi.system.service.app.pdf.ResumeAttachmentStorage;

/** 求职者简历附加文件服务实现。 */
@Service
public class AgentResumeAttachmentServiceImpl implements IAgentResumeAttachmentService
{
    private static final int MAX_ATTACHMENTS = 10;

    @Autowired
    private AgentResumeAttachmentMapper attachmentMapper;

    @Autowired
    private ResumeAttachmentStorage attachmentStorage;

    @Override
    public List<AgentResumeAttachment> list(Long userId, Long resumeId)
    {
        requireResume(userId, resumeId);
        List<AgentResumeAttachment> attachments = attachmentMapper.selectList(userId, resumeId);
        attachments.forEach(this::decorate);
        return attachments;
    }

    @Override
    @Transactional
    public List<AgentResumeAttachment> add(Long userId, Long resumeId, MultipartFile[] files) throws Exception
    {
        requireResume(userId, resumeId);
        if (files == null || files.length == 0) throw new ServiceException("请选择要添加的附件");
        int current = attachmentMapper.countActive(userId, resumeId);
        if (current + files.length > MAX_ATTACHMENTS) throw new ServiceException("每份简历最多添加10个附件");
        for (MultipartFile file : files)
        {
            ResumeAttachmentStorage.StoredAttachment stored = attachmentStorage.store(userId, file);
            registerCleanup(userId, stored.reference(), false);
            AgentResumeAttachment attachment = new AgentResumeAttachment();
            attachment.setResumeId(resumeId);
            attachment.setFileName(stored.name());
            attachment.setFileSize(stored.size());
            attachment.setContentType(stored.contentType());
            attachment.setFilePath(stored.reference());
            if (attachmentMapper.insert(attachment) <= 0)
                throw new ServiceException("保存附件信息失败，请稍后重试");
        }
        return list(userId, resumeId);
    }

    @Override
    public AppResumeAttachmentDocument file(Long userId, Long resumeId, Long attachmentId)
    {
        AgentResumeAttachment attachment = requireAttachment(userId, resumeId, attachmentId);
        return new AppResumeAttachmentDocument(attachmentStorage.read(userId, attachment.getFilePath()),
                attachment.getFileName(), attachment.getContentType());
    }

    @Override
    @Transactional
    public List<AgentResumeAttachment> delete(Long userId, Long resumeId, Long attachmentId)
    {
        AgentResumeAttachment attachment = requireAttachment(userId, resumeId, attachmentId);
        if (attachmentMapper.softDelete(userId, resumeId, attachmentId) <= 0)
            throw new ServiceException("删除附件失败，请稍后重试");
        registerCleanup(userId, attachment.getFilePath(), true);
        return list(userId, resumeId);
    }

    private void requireResume(Long userId, Long resumeId)
    {
        if (resumeId == null || attachmentMapper.countOwnedResume(userId, resumeId) <= 0)
            throw new ServiceException("简历不存在、已停用或不属于当前用户");
    }

    private AgentResumeAttachment requireAttachment(Long userId, Long resumeId, Long attachmentId)
    {
        requireResume(userId, resumeId);
        if (attachmentId == null) throw new ServiceException("附件编号不能为空");
        AgentResumeAttachment attachment = attachmentMapper.selectById(userId, resumeId, attachmentId);
        if (attachment == null) throw new ServiceException("附件不存在或无权访问");
        return attachment;
    }

    private void decorate(AgentResumeAttachment attachment)
    {
        attachment.setFileUrl("/agent/v1/resumes/" + attachment.getResumeId() + "/attachments/"
                + attachment.getId() + "/file");
    }

    private void registerCleanup(Long userId, String reference, boolean afterCommit)
    {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization()
        {
            @Override
            public void afterCompletion(int status)
            {
                if ((afterCommit && status == STATUS_COMMITTED) || (!afterCommit && status != STATUS_COMMITTED))
                    attachmentStorage.delete(userId, reference);
            }
        });
    }
}