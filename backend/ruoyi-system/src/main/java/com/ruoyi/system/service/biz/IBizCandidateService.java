package com.ruoyi.system.service.biz;

import java.util.List;
import java.util.Map;

/**
 * 平台运营 - 候选人监管 服务接口
 *
 * @author TQY
 */
public interface IBizCandidateService
{
    List<Map<String, Object>> selectAdminCandidateList(String userName, String status, String tags);

    Map<String, Object> selectAdminCandidateById(Long talId);

    /**
     * 变更候选人状态并写状态变更日志
     */
    int updateCandidateStatus(Long talId, Integer status, String reason, Long operatorId);

    /**
     * 单候选人覆盖标签（先清后插），remark 降级不持久化
     */
    int batchUpdateTag(Long talId, String tagsCsv, String remark);

    /**
     * 批量给多个候选人打相同标签（先清后插）
     */
    int batchUpdateTags(List<Long> talIds, String tagsCsv);

    /**
     * 候选人状态变更历史（时间正序）
     */
    List<Map<String, Object>> selectTalStatusLogs(Long talId);

    /**
     * 候选人统计概览
     */
    List<Map<String, Object>> selectCandidateSummary();
}
