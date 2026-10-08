package com.ruoyi.system.mapper.app;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.app.AppFeedback;
import com.ruoyi.system.domain.app.AppHelpArticle;

/** C-App 帮助与服务数据访问。 */
public interface AppSupportMapper
{
    List<AppHelpArticle> selectHelpArticles(@Param("keyword") String keyword,
                                            @Param("category") String category,
                                            @Param("limit") Integer limit);

    List<AppFeedback> selectFeedbacks(@Param("userId") Long userId,
                                      @Param("limit") Integer limit);

    int countRecentDuplicateFeedback(@Param("userId") Long userId,
                                     @Param("type") Integer type,
                                     @Param("subject") String subject,
                                     @Param("description") String description);

    int insertFeedback(@Param("userId") Long userId,
                       @Param("type") Integer type,
                       @Param("subject") String subject,
                       @Param("description") String description);
}
