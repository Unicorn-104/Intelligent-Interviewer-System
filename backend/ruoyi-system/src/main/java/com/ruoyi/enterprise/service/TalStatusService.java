package com.ruoyi.enterprise.service;

import java.util.Collection;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.enterprise.mapper.TalStatusMapper;

/**
 * 候选人状态机：所有 tal_status 变更必须经过本服务，保证“守卫 + 日志 + 流程实例推进”同时生效。
 *
 * <p>业务约定（t_tal.tal_status）：0 新入库、1 初筛通过、2 面试中、3 已淘汰、4 已录用、
 * 5 待笔试、6 笔试中、7 笔试通过、8 笔试未通过、9 笔试缺考。</p>
 *
 * @author enterprise
 */
@Service
public class TalStatusService
{
    public static final int TAL_NEW = 0;
    public static final int TAL_SCREENED = 1;
    public static final int TAL_INTERVIEWING = 2;
    public static final int TAL_REJECTED = 3;
    public static final int TAL_OFFERED = 4;
    public static final int TAL_PENDING_EXAM = 5;
    public static final int TAL_EXAM_TAKING = 6;
    public static final int TAL_EXAM_PASSED = 7;
    public static final int TAL_EXAM_FAILED = 8;
    public static final int TAL_EXAM_ABSENT = 9;

    /** 已淘汰、已录用为终态，任何环节都不得再推进 */
    public static final List<Integer> TERMINAL = List.of(TAL_REJECTED, TAL_OFFERED);

    private final TalStatusMapper talStatusMapper;

    public TalStatusService(TalStatusMapper talStatusMapper)
    {
        this.talStatusMapper = talStatusMapper;
    }

    /**
     * 按状态机推进候选人状态。
     *
     * @param allowedFrom 允许的当前状态集合，命中终态时不流转
     * @param positionId  触发流转的岗位，传空则不改流程实例
     * @param archiveSource 归档来源（淘汰时写入）：1 笔试淘汰、2 面试淘汰、4 初筛淘汰
     * @param examRecordId 笔试记录ID，仅笔试流转传入
     * @return true 表示状态已推进或已是目标状态；false 表示当前状态不允许流转
     */
    @Transactional(rollbackFor = Exception.class)
    public boolean change(Long talId, int toStatus, Collection<Integer> allowedFrom, Long positionId,
            Integer archiveSource, Long examRecordId, String reason, Long operatorId)
    {
        if (talId == null) return false;
        Integer current = talStatusMapper.lockTalStatus(talId);
        if (current == null || !allowedFrom.contains(current)) return false;
        if (current == toStatus)
        {
            // 幂等：状态已一致，只补齐归档来源并推进实例，不重复写日志
            if (archiveSource != null)
                talStatusMapper.updateTalStatus(talId, current, toStatus, examRecordId, archiveSource);
            advanceProcessInstance(talId, positionId, toStatus);
            return true;
        }
        if (talStatusMapper.updateTalStatus(talId, current, toStatus, examRecordId, archiveSource) == 0) return false;
        talStatusMapper.insertStatusLog(talId, current, toStatus, reason, operatorId);
        advanceProcessInstance(talId, positionId, toStatus);
        return true;
    }

    public boolean change(Long talId, int toStatus, Collection<Integer> allowedFrom, Long positionId,
            Integer archiveSource, String reason, Long operatorId)
    {
        return change(talId, toStatus, allowedFrom, positionId, archiveSource, null, reason, operatorId);
    }

    /** 淘汰=终止实例、录用=完成实例；撤回由投递模块单独终止 */
    private void advanceProcessInstance(Long talId, Long positionId, int toStatus)
    {
        if (positionId == null) return;
        if (toStatus == TAL_REJECTED)
            talStatusMapper.updateProcessInstanceStatus(talId, positionId, List.of(0), 3);
        else if (toStatus == TAL_OFFERED)
            talStatusMapper.updateProcessInstanceStatus(talId, positionId, List.of(0), 1);
    }
}
