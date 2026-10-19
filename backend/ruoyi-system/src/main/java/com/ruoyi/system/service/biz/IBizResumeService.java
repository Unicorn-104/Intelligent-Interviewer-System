package com.ruoyi.system.service.biz;

import java.util.List;
import java.util.Map;

/**
 * 平台运营 - 简历库 服务接口（降级实现）
 *
 * @author TQY
 */
public interface IBizResumeService
{
    List<Map<String, Object>> selectAdminResumeList(String name, String jobName, String source);

    Map<String, Object> selectAdminResumeById(Long rbsId);

    int deleteResumeByIds(Long[] rbsIds);
}
