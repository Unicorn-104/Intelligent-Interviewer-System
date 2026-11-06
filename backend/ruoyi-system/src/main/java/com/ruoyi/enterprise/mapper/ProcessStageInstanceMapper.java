package com.ruoyi.enterprise.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.enterprise.domain.ProcessStageInstance;

/**
 * 招聘流程节点实例数据层：管理每一轮笔试/面试节点的创建、推进与查询。
 *
 * @author tqy
 */
public interface ProcessStageInstanceMapper
{
    /** 锁定父流程实例行（FOR UPDATE），串行化同实例下节点的查询/轮次/插入 */
    Long lockProcessInstance(@Param("instanceId") Long instanceId);

    /** 新建节点，回填自增主键 */
    int insertNode(ProcessStageInstance node);

    /** 守卫更新节点状态（限定当前状态），可选写入开始/结束时间 */
    int updateNodeStatus(@Param("id") Long id, @Param("fromStatus") int fromStatus,
            @Param("toStatus") int toStatus, @Param("startAt") Boolean startAt,
            @Param("endAt") Boolean endAt);

    /** 写入节点结果与结束时间（限定节点已完成） */
    int updateNodeResult(@Param("id") Long id, @Param("result") Integer result,
            @Param("resultNote") String resultNote);

    /** 按节点ID查询 */
    ProcessStageInstance selectNodeById(@Param("id") Long id);

    /** 按业务单据（笔试记录/面试预约）查询节点，幂等防重复创建 */
    ProcessStageInstance selectNodeByRef(@Param("refId") Long refId);

    /** 某流程实例下全部节点，按创建顺序排列 */
    List<ProcessStageInstance> listNodesByInstance(@Param("instanceId") Long instanceId);

    /** 当前节点：优先进行中/待开始节点，否则取最近完成节点；无节点返回 null */
    ProcessStageInstance selectCurrentNode(@Param("instanceId") Long instanceId);

    /** 同类型分组内已用最大轮次，用于计算第 N 轮 */
    Integer selectMaxRound(@Param("instanceId") Long instanceId,
            @Param("nodeTypes") List<Integer> nodeTypes);
}
