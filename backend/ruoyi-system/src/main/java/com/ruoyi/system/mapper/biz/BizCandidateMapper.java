package com.ruoyi.system.mapper.biz;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/**
 * 平台运营 - 候选人监管 数据层（跨企业视角）
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
     * 更新候选人状态
     */
    int updateCandidateStatus(@Param("talId") Long talId, @Param("status") Integer status);
}
