package com.ruoyi.system.service.app.impl;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.app.AppFeedback;
import com.ruoyi.system.domain.app.AppFeedbackRequest;
import com.ruoyi.system.domain.app.AppHelpArticle;
import com.ruoyi.system.mapper.app.AppSupportMapper;
import com.ruoyi.system.service.app.IAppSupportService;

@Service
public class AppSupportServiceImpl implements IAppSupportService
{
    @Autowired
    private AppSupportMapper supportMapper;

    @Override
    public List<AppHelpArticle> selectHelpArticles(String keyword, String category, Integer limit)
    {
        int safeLimit = limit == null ? 50 : Math.max(1, Math.min(limit, 100));
        return supportMapper.selectHelpArticles(normalizeOptional(keyword), normalizeOptional(category), safeLimit);
    }

    @Override
    public List<AppFeedback> selectFeedbacks(Long userId, Integer limit)
    {
        int safeLimit = limit == null ? 20 : Math.max(1, Math.min(limit, 50));
        return supportMapper.selectFeedbacks(userId, safeLimit);
    }

    @Override
    @Transactional
    public void submitFeedback(Long userId, AppFeedbackRequest request)
    {
        String subject = request.getSubject() == null ? "" : request.getSubject().trim();
        String description = request.getDescription() == null ? "" : request.getDescription().trim();
        if (subject.isEmpty())
        {
            throw new ServiceException("反馈标题不能为空");
        }
        if (description.isEmpty())
        {
            throw new ServiceException("请填写详细描述");
        }
        if (supportMapper.countRecentDuplicateFeedback(
                userId, request.getType(), subject, description) > 0)
        {
            throw new ServiceException("请勿重复提交相同反馈");
        }
        if (supportMapper.insertFeedback(
                userId, request.getType(), subject, description) <= 0)
        {
            throw new ServiceException("反馈提交失败，请稍后重试");
        }
    }

    private String normalizeOptional(String value)
    {
        if (value == null || value.isBlank())
        {
            return null;
        }
        return value.trim();
    }
}
