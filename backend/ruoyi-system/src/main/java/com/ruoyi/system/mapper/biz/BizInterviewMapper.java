package com.ruoyi.system.mapper.biz;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/**
 * 平台运营 - 面试会话监管 数据层（跨企业视角）
 *
 * @author TQY
 */
@Mapper
public interface BizInterviewMapper
{
    List<Map<String, Object>> selectAdminInterviewList();

    Map<String, Object> selectAdminInterviewById(@Param("sesId") Long sesId);

    /**
     * 强制结束：置为已完成态(2)，reason 降级不持久化
     */
    int terminateInterview(@Param("sesId") Long sesId);
}
