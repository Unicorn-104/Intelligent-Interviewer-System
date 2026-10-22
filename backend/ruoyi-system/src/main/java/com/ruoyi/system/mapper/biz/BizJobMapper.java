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

    /**
     * 写入岗位状态变更日志（审核通过 / 违规下架原因与操作时间）
     */
    int insertPosStatusLog(@Param("posId") Long posId,
                           @Param("fromStatus") Integer fromStatus,
                           @Param("toStatus") Integer toStatus,
                           @Param("reason") String reason,
                           @Param("operatorId") Long operatorId);

    /**
     * 查询岗位最新一条状态变更日志（取处理原因与操作时间）
     */
    Map<String, Object> selectLatestPosLog(@Param("posId") Long posId);

    /**
     * 查询岗位全部状态变更日志（变更历史时间线，按时间正序）
     */
    List<Map<String, Object>> selectPosStatusLogs(@Param("posId") Long posId);
}
