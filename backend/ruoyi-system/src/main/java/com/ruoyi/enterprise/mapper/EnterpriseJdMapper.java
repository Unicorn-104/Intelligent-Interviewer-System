package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 岗位画像（JD Profile）数据层
 *
 * <p>依据《业务功能分析》UC-01：岗位画像快照存 t_pos.pos_jd_json，
 * 技能标签存 t_pos_skill。</p>
 *
 * @author enterprise
 */
public interface EnterpriseJdMapper
{
    /** 岗位基础信息 + 画像快照 */
    public Map<String, Object> selectPositionJd(@Param("posId") Long posId);

    /** 更新画像快照（pos_jd_json） */
    public int updatePositionJd(@Param("posId") Long posId, @Param("jdJson") String jdJson);

    /** 岗位技能标签列表 */
    public List<Map<String, Object>> selectPositionSkills(@Param("posId") Long posId);

    /** 删除岗位全部技能标签（解析重建前调用） */
    public int deletePositionSkills(@Param("posId") Long posId);

    /** 新增技能标签 */
    public int insertPositionSkill(@Param("posId") Long posId, @Param("name") String name,
            @Param("required") Integer required);
}
