package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.enterprise.domain.EntResumeSnapshot;

/**
 * 企业投递简历快照数据层。
 *
 * <p>仅提供插入与读取，不提供更新/删除快照内容的方法，以落实快照不可变；
 * 合法数据删除由独立受控的企业生命周期流程另行实现。</p>
 */
public interface EntResumeSnapshotMapper
{
    /** 插入快照主表，回填自增主键。 */
    int insertSnapshot(EntResumeSnapshot snapshot);

    /** 批量插入教育经历。 */
    int insertEducationList(@Param("snapshotId") Long snapshotId,
            @Param("list") List<EntResumeSnapshot.Education> list);

    /** 批量插入工作经历。 */
    int insertWorkList(@Param("snapshotId") Long snapshotId,
            @Param("list") List<EntResumeSnapshot.Work> list);

    /** 批量插入项目经历。 */
    int insertProjectList(@Param("snapshotId") Long snapshotId,
            @Param("list") List<EntResumeSnapshot.Project> list);

    /** 批量插入技能。 */
    int insertSkillList(@Param("snapshotId") Long snapshotId,
            @Param("list") List<EntResumeSnapshot.Skill> list);

    /** 按投递ID查询完整快照（含子表）。 */
    EntResumeSnapshot selectByAppId(@Param("appId") Long appId);

    /** 按快照ID查询完整快照（含子表）。 */
    EntResumeSnapshot selectById(@Param("id") Long id);

    /** 统计某投递是否已有快照，用于幂等判断。 */
    int countByAppId(@Param("appId") Long appId);

    /**
     * 投递企业归属校验（为投递级快照读取服务）：关联 t_pos 校验企业，
     * 返回投递简要信息；投递不存在或不属于当前企业时返回 null。
     *
     * @param appId 投递ID
     * @param companyId 当前登录企业ID
     */
    Map<String, Object> selectApplicationOwnership(@Param("appId") Long appId,
            @Param("companyId") Long companyId);
}
