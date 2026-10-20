package com.ruoyi.system.service.biz;

import java.util.List;
import java.util.Map;

/**
 * 平台运营 - 面试会话监管 服务接口
 *
 * @author TQY
 */
public interface IBizInterviewService
{
    List<Map<String, Object>> selectAdminInterviewList();

    Map<String, Object> selectAdminInterviewById(Long sesId);

    /**
     * 强制结束进行中的面试，reason 降级不持久化
     */
    int terminateInterview(Long sesId, String reason);
}
