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

    int updateCandidateStatus(Long talId, Integer status);

    /**
     * 批量覆盖候选人标签（先清后插），remark 降级不持久化
     */
    int batchUpdateTag(Long talId, String tagsCsv, String remark);
}
