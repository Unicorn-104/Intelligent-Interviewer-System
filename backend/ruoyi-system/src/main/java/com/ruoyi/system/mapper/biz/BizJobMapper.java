package com.ruoyi.system.mapper.biz;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/**
 * 平台运营 - 岗位监管 数据层（跨企业视角）
 *
 * @author TQY
 */
@Mapper
public interface BizJobMapper
{
    /**
     * 平台岗位列表：跨企业分页查询，支持岗位名/企业名/状态过滤
     */
    List<Map<String, Object>> selectAdminJobList(@Param("jobName") String jobName,
                                                 @Param("companyName") String companyName,
                                                 @Param("status") Integer status);

    /**
     * 平台岗位详情
     */
    Map<String, Object> selectAdminJobById(@Param("posId") Long posId);

    /**
     * 更新岗位状态（1在招发布 / 2下架），不限企业
     */
    int updateJobStatus(@Param("posId") Long posId, @Param("status") Integer status);
}
