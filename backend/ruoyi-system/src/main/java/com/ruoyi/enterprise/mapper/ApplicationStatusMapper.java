package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 岗位投递状态机数据层：承载 app_status 守卫更新、终止字段、状态日志与流程实例收尾。
 *
 * <p>所有 app_status 变更只能经本数据层配合 ApplicationStatusService 完成，
 * 禁止在业务代码中直接 update t_app_record.app_status 绕过状态机。</p>
 *
 * @author tqy
 */
public interface ApplicationStatusMapper
{
    /** 行锁：按投递ID加锁读取当前 app_status，记录不存在返回 null */
    Integer lockAppStatus(@Param("appId") Long appId);

    /** 按候选人+岗位定位投递ID（候选人撤回等场景使用） */
    Long selectAppId(@Param("candidateId") Long candidateId, @Param("positionId") Long positionId);

    /** 读取投递基础信息（存在性/归属校验） */
    Map<String, Object> selectApplicationById(@Param("appId") Long appId);

    /** 守卫更新：仅当当前状态=fromStatus 时才改 app_status，返回影响行数 */
    int updateAppStatus(@Param("appId") Long appId, @Param("fromStatus") int fromStatus,
            @Param("toStatus") int toStatus);

    /** 写入终止字段，仅进入未录用（5）时由状态机调用 */
    int updateEndFields(@Param("appId") Long appId, @Param("endReason") String endReason,
            @Param("endedBy") Long endedBy, @Param("endRemark") String endRemark);

    /** 清空终止字段（仅管理员独立授权纠错使用，普通业务不调用） */
    int clearEndFields(@Param("appId") Long appId);

    /** 是否已存在终止原因：幂等重复终止时用于判断是否需要补写，避免覆盖首次终止记录 */
    boolean existsEndReason(@Param("appId") Long appId);

    /** 写岗位投递状态变更日志 */
    int insertStatusLog(@Param("appId") Long appId, @Param("candidateId") Long candidateId,
            @Param("positionId") Long positionId, @Param("fromStatus") Integer fromStatus,
            @Param("toStatus") int toStatus, @Param("operatorId") Long operatorId,
            @Param("source") String source, @Param("reason") String reason);

    /** 流程实例收尾：未录用→pin_status=3、已录用→pin_status=1 */
    int updateProcessInstanceStatus(@Param("candidateId") Long candidateId,
            @Param("positionId") Long positionId, @Param("fromStatuses") List<Integer> fromStatuses,
            @Param("toStatus") int toStatus);
}
