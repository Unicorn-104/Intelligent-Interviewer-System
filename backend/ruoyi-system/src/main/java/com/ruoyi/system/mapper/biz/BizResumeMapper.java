package com.ruoyi.system.mapper.biz;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/**
 * 平台运营 - 简历库 数据层（跨用户视角，降级实现）
 *
 * @author TQY
 */
@Mapper
public interface BizResumeMapper
{
    List<Map<String, Object>> selectAdminResumeList(@Param("name") String name,
                                                    @Param("jobName") String jobName,
                                                    @Param("source") String source);

    Map<String, Object> selectAdminResumeById(@Param("rbsId") Long rbsId);

    List<Map<String, Object>> selectWorkList(@Param("rbsId") Long rbsId);

    List<Map<String, Object>> selectEduList(@Param("rbsId") Long rbsId);

    List<Map<String, Object>> selectSkillList(@Param("rbsId") Long rbsId);

    List<Map<String, Object>> selectProjList(@Param("rbsId") Long rbsId);

    List<Map<String, Object>> selectResumeSummary();

    int deleteResumeByIds(@Param("rbsIds") Long[] rbsIds);
}
