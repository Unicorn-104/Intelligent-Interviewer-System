package com.ruoyi.system.service.biz;

import java.util.List;
import java.util.Map;

/**
 * 平台运营 - 岗位监管 服务接口
 *
 * @author TQY
 */
public interface IBizJobService
{
    /**
     * 平台岗位列表（跨企业）
     */
    List<Map<String, Object>> selectAdminJobList(String jobName, String companyName, Integer status);

    /**
     * 岗位详情
     */
    Map<String, Object> selectAdminJobById(Long posId);

    /**
     * 岗位审核：result=1 通过发布(置1)；result=2 违规下架(置2)
     */
    int auditJob(Long posId, Integer result, String reason);
}
