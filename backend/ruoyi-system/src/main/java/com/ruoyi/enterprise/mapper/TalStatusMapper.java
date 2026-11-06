package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 候选人状态流转数据层：统一承载状态写入、归档来源、流程实例推进与状态日志。
 *
 * @author enterprise
 */
public interface TalStatusMapper
{
    /** 加锁读取候选人当前状态，用于状态机守卫 */
    Integer lockTalStatus(@Param("talId") Long talId);

    /** 按当前状态守卫更新候选人状态；examRecordId / archiveSource 为空时不覆盖 */
    int updateTalStatus(@Param("talId") Long talId, @Param("fromStatus") int fromStatus,
            @Param("toStatus") int toStatus, @Param("examRecordId") Long examRecordId,
            @Param("archiveSource") Integer archiveSource);

    /** 推进指定岗位的流程实例状态：淘汰=3、撤回=2、录用完成=1 */
    int updateProcessInstanceStatus(@Param("talId") Long talId, @Param("positionId") Long positionId,
            @Param("fromStatuses") List<Integer> fromStatuses, @Param("toStatus") int toStatus);

    /** 写候选人状态变更日志，供人才库归档来源与求职者端时间线使用 */
    int insertStatusLog(@Param("talId") Long talId, @Param("fromStatus") Integer fromStatus,
            @Param("toStatus") int toStatus, @Param("reason") String reason,
            @Param("operatorId") Long operatorId);

    /**
     * 统计该候选人仍处于活跃投递（新六态 0/1/2/3：已投递/招聘中/待发Offer/待确认Offer）的岗位投递数。
     * 终态聚合守卫用：用于判断是否可把全局 tal_status 翻转为已录用/已淘汰。
     */
    int countActiveApplications(@Param("talId") Long talId);

    /**
     * 同上，但排除触发本次终态写入的岗位，避免因时序（本岗位 app_status 尚未落终态）误判。
     */
    int countActiveApplicationsExcludingPosition(@Param("talId") Long talId,
            @Param("positionId") Long positionId);
}
