package com.ruoyi.enterprise.domain;

import java.time.LocalDateTime;

/**
 * 招聘流程节点实例（t_process_instance_stage）：每一轮笔试/面试/实操的独立节点。
 *
 * <p>节点与岗位投递记录关联，记录节点类型、轮次、执行状态、结果和时间；
 * 节点结果不等同于整个岗位投递的最终结果，整体阶段只看 t_app_record.app_status。</p>
 *
 * @author tqy
 */
public class ProcessStageInstance
{
    /** 节点状态：0 待开始、1 进行中、2 已完成、3 已取消 */
    public static final int STATUS_PENDING = 0;
    public static final int STATUS_RUNNING = 1;
    public static final int STATUS_COMPLETED = 2;
    public static final int STATUS_CANCELLED = 3;

    /** 节点结果：1 通过、2 未通过、3 缺考、4 取消 */
    public static final int RESULT_PASS = 1;
    public static final int RESULT_FAIL = 2;
    public static final int RESULT_ABSENT = 3;
    public static final int RESULT_CANCELLED = 4;

    /** 节点类型（与 t_process_stage.psg_type 同口径）：1 在线笔试、2 AI 技术面试、3 HR 综合面试、4 编程实操 */
    public static final int TYPE_EXAM = 1;
    public static final int TYPE_AI_INTERVIEW = 2;
    public static final int TYPE_HR_INTERVIEW = 3;
    public static final int TYPE_PRACTICE = 4;

    private Long id;
    private Long instanceId;
    private Long stageId;
    private Integer nodeType;
    private Integer round;
    private Integer status;
    private Integer result;
    private Long refId;
    private String nodeName;
    private Long operatorId;
    private LocalDateTime startAt;
    private LocalDateTime endAt;
    private String resultNote;
    private LocalDateTime createdAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getInstanceId() { return instanceId; }
    public void setInstanceId(Long instanceId) { this.instanceId = instanceId; }
    public Long getStageId() { return stageId; }
    public void setStageId(Long stageId) { this.stageId = stageId; }
    public Integer getNodeType() { return nodeType; }
    public void setNodeType(Integer nodeType) { this.nodeType = nodeType; }
    public Integer getRound() { return round; }
    public void setRound(Integer round) { this.round = round; }
    public Integer getStatus() { return status; }
    public void setStatus(Integer status) { this.status = status; }
    public Integer getResult() { return result; }
    public void setResult(Integer result) { this.result = result; }
    public Long getRefId() { return refId; }
    public void setRefId(Long refId) { this.refId = refId; }
    public String getNodeName() { return nodeName; }
    public void setNodeName(String nodeName) { this.nodeName = nodeName; }
    public Long getOperatorId() { return operatorId; }
    public void setOperatorId(Long operatorId) { this.operatorId = operatorId; }
    public LocalDateTime getStartAt() { return startAt; }
    public void setStartAt(LocalDateTime startAt) { this.startAt = startAt; }
    public LocalDateTime getEndAt() { return endAt; }
    public void setEndAt(LocalDateTime endAt) { this.endAt = endAt; }
    public String getResultNote() { return resultNote; }
    public void setResultNote(String resultNote) { this.resultNote = resultNote; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    /** 是否笔试类节点（用于轮次归类与展示） */
    public boolean isExamGroup() { return nodeType != null && nodeType == TYPE_EXAM; }

    /** 是否面试类节点（AI 技术面试与 HR 综合面试） */
    public boolean isInterviewGroup() { return nodeType != null && (nodeType == TYPE_AI_INTERVIEW || nodeType == TYPE_HR_INTERVIEW); }
}
