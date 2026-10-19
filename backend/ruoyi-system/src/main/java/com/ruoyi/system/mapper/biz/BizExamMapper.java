package com.ruoyi.system.mapper.biz;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;

/**
 * 平台运营 - 考核记录 数据层
 *
 * @author TQY
 */
@Mapper
public interface BizExamMapper
{
    /**
     * 最近考核记录（跨企业，限 10 条由 service 控制）
     */
    List<Map<String, Object>> selectAdminExamRecords();
}
