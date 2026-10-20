package com.ruoyi.system.mapper.biz;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/**
 * 平台运营 - 候选人监管 数据层（跨公司视角）
 *
 * @author TQY
 */
@Mapper
public interface BizCandidateMapper
{
    /**
     * 候选人列表：跨公司，支持姓名/状态/标签过滤
     */
    List<Map<String, Object>> selectAdminCandidateList(@Param("userName") String userName,
                                                       @Param("status") String status,
                                                       @Param("tags") String tags);

    /**
     * 候选人详情
     */
    Map<String, Object> selectAdminCandidateById(@Param("talId") Long talId);

    /**
     * 候选人现有标签
     */
    List<String> selectCandidateTags(@Param("talId") Long talId);

    /**
     * 删除候选人全部标签
     */
    int deleteCandidateTags(@Param("talId") Long talId);

    /**
     * 插入单个标签
     */
    int insertCandidateTag(@Param("talId") Long talId, @Param("name") String name);

    /**
     * 更新候选人状态（并由 Service 写状态变更日志）
     */
    int updateCandidateStatus(@Param("talId") Long talId, @Param("status") Integer status);

    /**
     * 回填触发器刚写入的最近一条状态日志的人工原因与操作人（触发器已自动建记录，不重复插入）
     */
    int updateTalStatusLogMeta(@Param("talId") Long talId, @Param("reason") String reason,
                              @Param("operatorId") Long operatorId);

    /**
     * 写入候选人状态变更日志
     */
    int insertTalStatusLog(@Param("talId") Long talId, @Param("fromStatus") Integer fromStatus,
                           @Param("toStatus") Integer toStatus, @Param("reason") String reason,
                           @Param("operatorId") Long operatorId);

    /**
     * 候选人全部状态变更日志（时间正序）
     */
    List<Map<String, Object>> selectTalStatusLogs(@Param("talId") Long talId);

    /**
     * 候选人统计概览：各状态人数、平均匹配分
     */
    List<Map<String, Object>> selectCandidateSummary();
}
