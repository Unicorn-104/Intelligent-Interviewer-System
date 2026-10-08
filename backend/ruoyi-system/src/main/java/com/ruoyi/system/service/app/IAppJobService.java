package com.ruoyi.system.service.app;

import java.util.List;
import com.ruoyi.system.domain.app.AppHomeData;
import com.ruoyi.system.domain.app.AppJob;

public interface IAppJobService
{
    AppHomeData selectHomeData(Long userId, String filter);
    List<AppJob> selectJobs(Long userId, String keyword, String filter, Integer limit);
    void apply(Long userId, Long positionId);
}
