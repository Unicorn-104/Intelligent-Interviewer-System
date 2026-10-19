package com.ruoyi.system.service.biz;

import java.util.List;
import java.util.Map;

/**
 * 平台运营 - 考核环境配置与记录 服务接口
 *
 * @author TQY
 */
public interface IBizExamService
{
    /** 考核环境配置（降级：无独立配置表，返回默认值） */
    Map<String, Object> getConfig();

    /** 保存配置（降级：不落库） */
    void saveConfig(Map<String, Object> body);

    /** 最近考核记录（最多 10 条） */
    List<Map<String, Object>> listRecords();
}
