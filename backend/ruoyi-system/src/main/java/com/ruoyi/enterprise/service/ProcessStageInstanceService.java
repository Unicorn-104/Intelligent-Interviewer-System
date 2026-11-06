package com.ruoyi.enterprise.service;

import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.domain.ProcessStageInstance;
import com.ruoyi.enterprise.mapper.ProcessStageInstanceMapper;

/**
 * 招聘流程节点实例服务：管理每一轮笔试/面试节点，并据真实节点计算当前环节。
 *
 * <p>当前环节由节点实例计算，不使用固定枚举推断；节点结果只描述该轮，
 * 不直接决定 t_app_record.app_status。</p>
 *
 * @author tqy
 */
@Service
public class ProcessStageInstanceService
{
    private final ProcessStageInstanceMapper mapper;

    public ProcessStageInstanceService(ProcessStageInstanceMapper mapper)
    {
        this.mapper = mapper;
    }

    /**
     * 按业务单据幂等获取节点；不存在则创建并自动计算轮次。
     *
     * @param nodeType 节点类型 1笔试 2AI面试 3HR面试 4实操
     * @param refId 业务单据ID（笔试记录/面试预约），用于幂等
     */
    @Transactional(rollbackFor = Exception.class)
    public ProcessStageInstance getOrCreate(Long instanceId, Long stageId, int nodeType, String nodeName,
            Long refId, Long operatorId)
    {
        if (instanceId == null)
            throw new ServiceException("流程实例ID不能为空，无法创建流程节点");
        // 先锁父流程实例行，锁覆盖后续查询/轮次/插入全过程，同实例节点创建串行化
        mapper.lockProcessInstance(instanceId);
        if (refId != null)
        {
            ProcessStageInstance existing = mapper.selectNodeByRef(refId);
            if (existing != null) return existing;
        }
        return createNode(instanceId, stageId, nodeType, nodeName, refId, operatorId);
    }

    /** 新建节点，轮次按同类型分组内最大值 +1 */
    @Transactional(rollbackFor = Exception.class)
    public ProcessStageInstance createNode(Long instanceId, Long stageId, int nodeType, String nodeName,
            Long refId, Long operatorId)
    {
        List<Integer> group = groupTypes(nodeType);
        Integer maxRound = mapper.selectMaxRound(instanceId, group);
        ProcessStageInstance node = new ProcessStageInstance();
        node.setInstanceId(instanceId);
        node.setStageId(stageId);
        node.setNodeType(nodeType);
        node.setRound((maxRound == null ? 0 : maxRound) + 1);
        node.setStatus(ProcessStageInstance.STATUS_PENDING);
        node.setRefId(refId);
        node.setNodeName(nodeName);
        node.setOperatorId(operatorId);
        mapper.insertNode(node);
        return node;
    }

    /** 节点开始：待开始→进行中 */
    @Transactional(rollbackFor = Exception.class)
    public void start(Long nodeId, Long operatorId)
    {
        mapper.updateNodeStatus(nodeId, ProcessStageInstance.STATUS_PENDING,
                ProcessStageInstance.STATUS_RUNNING, true, false);
    }

    /** 节点完成并写结果：进行中/待开始→已完成 */
    @Transactional(rollbackFor = Exception.class)
    public void complete(Long nodeId, Integer result, String resultNote)
    {
        mapper.updateNodeResult(nodeId, result, resultNote);
    }

    /** 节点取消：待开始/进行中→已取消 */
    @Transactional(rollbackFor = Exception.class)
    public void cancel(Long nodeId, String note)
    {
        mapper.updateNodeStatus(nodeId, ProcessStageInstance.STATUS_PENDING,
                ProcessStageInstance.STATUS_CANCELLED, false, true);
        // 进行中节点同样可取消，再尝试一次
        mapper.updateNodeStatus(nodeId, ProcessStageInstance.STATUS_RUNNING,
                ProcessStageInstance.STATUS_CANCELLED, false, true);
    }

    public ProcessStageInstance getCurrentNode(Long instanceId)
    {
        return mapper.selectCurrentNode(instanceId);
    }

    public List<ProcessStageInstance> listNodes(Long instanceId)
    {
        return mapper.listNodesByInstance(instanceId);
    }

    /**
     * 计算「招聘中」旁注文案，如“第 2 轮笔试进行中”；无节点返回“待安排下一环节”。
     * 仅用于展示，不写库。
     */
    public String currentNodeLabel(Long instanceId)
    {
        ProcessStageInstance node = mapper.selectCurrentNode(instanceId);
        if (node == null) return "待安排下一环节";
        return describe(node);
    }

    /** 单节点完整描述：第 N 轮 + 类型 + 状态/结果 */
    public String describe(ProcessStageInstance node)
    {
        StringBuilder text = new StringBuilder();
        text.append("第 ").append(node.getRound()).append(" 轮").append(typeLabel(node.getNodeType()));
        text.append(statusText(node));
        return text.toString();
    }

    /** 类型分组：笔试 / 面试 / 实操 */
    private List<Integer> groupTypes(int nodeType)
    {
        if (nodeType == ProcessStageInstance.TYPE_EXAM) return List.of(ProcessStageInstance.TYPE_EXAM);
        if (nodeType == ProcessStageInstance.TYPE_PRACTICE)
            return List.of(ProcessStageInstance.TYPE_PRACTICE);
        return List.of(ProcessStageInstance.TYPE_AI_INTERVIEW, ProcessStageInstance.TYPE_HR_INTERVIEW);
    }

    private String typeLabel(Integer nodeType)
    {
        if (nodeType == null) return "环节";
        return switch (nodeType)
        {
            case ProcessStageInstance.TYPE_EXAM -> "笔试";
            case ProcessStageInstance.TYPE_AI_INTERVIEW, ProcessStageInstance.TYPE_HR_INTERVIEW -> "面试";
            case ProcessStageInstance.TYPE_PRACTICE -> "实操";
            default -> "环节";
        };
    }

    private String statusText(ProcessStageInstance node)
    {
        Integer status = node.getStatus();
        if (status == null) return "";
        return switch (status)
        {
            case ProcessStageInstance.STATUS_PENDING -> "待开始";
            case ProcessStageInstance.STATUS_RUNNING -> "进行中";
            case ProcessStageInstance.STATUS_CANCELLED -> "已取消";
            case ProcessStageInstance.STATUS_COMPLETED -> resultText(node.getResult());
            default -> "";
        };
    }

    private String resultText(Integer result)
    {
        if (result == null) return "已完成";
        return switch (result)
        {
            case ProcessStageInstance.RESULT_PASS -> "已通过";
            case ProcessStageInstance.RESULT_FAIL -> "未通过";
            case ProcessStageInstance.RESULT_ABSENT -> "缺考";
            case ProcessStageInstance.RESULT_CANCELLED -> "已取消";
            default -> "已完成";
        };
    }
}
