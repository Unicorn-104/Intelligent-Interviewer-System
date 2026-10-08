package com.ruoyi.system.service.app;

import java.util.List;
import com.ruoyi.system.domain.app.AppFeedback;
import com.ruoyi.system.domain.app.AppFeedbackRequest;
import com.ruoyi.system.domain.app.AppHelpArticle;

/** C-App 帮助与服务。 */
public interface IAppSupportService
{
    List<AppHelpArticle> selectHelpArticles(String keyword, String category, Integer limit);

    List<AppFeedback> selectFeedbacks(Long userId, Integer limit);

    void submitFeedback(Long userId, AppFeedbackRequest request);
}
