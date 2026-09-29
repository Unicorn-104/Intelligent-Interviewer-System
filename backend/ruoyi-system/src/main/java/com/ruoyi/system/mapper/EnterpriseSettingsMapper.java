package com.ruoyi.system.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业系统设置数据层（模板/部门/集成/成员）
 *
 * @author ruoyi
 */
public interface EnterpriseSettingsMapper
{
    /** 公司模板列表（含平台全局模板） */
    public List<Map<String, Object>> selectTemplates(@Param("companyId") Long companyId);

    public int insertTemplate(@Param("companyId") Long companyId, @Param("code") String code,
            @Param("title") String title, @Param("content") String content, @Param("channel") Integer channel);

    public int updateTemplate(@Param("id") Long id, @Param("companyId") Long companyId, @Param("title") String title,
            @Param("content") String content, @Param("channel") Integer channel, @Param("status") Integer status);

    public int deleteTemplate(@Param("id") Long id, @Param("companyId") Long companyId);

    /** 部门列表（含成员数、在招岗位数） */
    public List<Map<String, Object>> selectDepts(@Param("companyId") Long companyId);

    public int countDepts(@Param("companyId") Long companyId);

    public int countMembers(@Param("companyId") Long companyId);

    public int countActivePositions(@Param("companyId") Long companyId);

    public int insertDept(@Param("companyId") Long companyId, @Param("parentId") Long parentId,
            @Param("deptName") String deptName, @Param("leader") String leader, @Param("orderNum") Integer orderNum);

    public int updateDept(@Param("id") Long id, @Param("companyId") Long companyId, @Param("deptName") String deptName,
            @Param("leader") String leader, @Param("orderNum") Integer orderNum, @Param("status") Integer status);

    public int deleteDept(@Param("id") Long id, @Param("companyId") Long companyId);

    public int countDeptChildren(@Param("id") Long id);

    public int countDeptMembers(@Param("id") Long id, @Param("companyId") Long companyId);

    /** 集成配置列表 */
    public List<Map<String, Object>> selectIntegrations(@Param("companyId") Long companyId);

    public int updateIntegration(@Param("companyId") Long companyId, @Param("provider") String provider,
            @Param("status") Integer status, @Param("configJson") String configJson);

    /** 公司成员列表（昵称/部门/角色/状态） */
    public List<Map<String, Object>> selectMembers(@Param("companyId") Long companyId);

    public int deleteUserBizRoles(@Param("userId") Long userId);

    public int updateUserStatus(@Param("userId") Long userId, @Param("companyId") Long companyId, @Param("status") String status);

    public int insertUser(@Param("userName") String userName, @Param("nickName") String nickName,
            @Param("email") String email, @Param("password") String password);

    public Long selectUserIdByName(@Param("userName") String userName);

    public int insertBinding(@Param("userId") Long userId, @Param("companyId") Long companyId, @Param("jobTitle") String jobTitle);

    public int insertUserRole(@Param("userId") Long userId, @Param("roleId") Long roleId);

    /** 最近备份时间（sys_config） */
    public String selectConfigValue(@Param("key") String key);

    public int updateConfigValue(@Param("key") String key, @Param("value") String value);

    public int insertConfig(@Param("name") String name, @Param("key") String key, @Param("value") String value);

    /** 导出：本公司候选人明细（姓名/岗位/状态/入库时间） */
    public List<Map<String, Object>> selectCandidateExportRows(@Param("companyId") Long companyId);

    /** 清理预览：已结束流程（淘汰/录用）且超过 years 年的候选人 */
    public List<Map<String, Object>> selectCleanupRows(@Param("companyId") Long companyId, @Param("years") int years);

    public int deleteStatusLogs(@Param("talIds") List<Long> talIds);

    public int deleteCandidates(@Param("companyId") Long companyId, @Param("talIds") List<Long> talIds);
}
