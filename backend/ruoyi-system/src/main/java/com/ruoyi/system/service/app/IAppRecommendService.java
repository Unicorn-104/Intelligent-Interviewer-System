package com.ruoyi.system.service.app;

import java.util.List;
import com.ruoyi.system.domain.app.AppJobRecommendation;
import com.ruoyi.system.domain.app.AppRecommendRequest;

/** C-App AI 简历推荐服务。 */
public interface IAppRecommendService
{
    List<AppJobRecommendation> recommend(Long userId, AppRecommendRequest request);
}
