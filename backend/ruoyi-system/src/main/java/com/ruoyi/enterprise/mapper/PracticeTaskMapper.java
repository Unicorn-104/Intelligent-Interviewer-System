package com.ruoyi.enterprise.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端 - 在线实操环境预加载数据层
 *
 * <p>依据《业务功能分析》UC-11：
 * 实操考题 t_practice_task（按场次模板/岗位匹配）。</p>
 *
 * @author enterprise
 */
public interface PracticeTaskMapper
{
    /** 场次基础信息（预加载校验用） */
    public Map<String, Object> selectSessionBase(@Param("sessionId") Long sessionId);

    /** 场次关联的实操考题（按模板或岗位匹配，状态启用） */
    public List<Map<String, Object>> selectTasks(@Param("sessionId") Long sessionId);
}
