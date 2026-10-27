package com.ruoyi.system.service;

import java.util.List;
import java.util.Map;

/**
 * 企业系统设置 服务层（模板/部门/集成/成员）
 *
 * @author ruoyi
 */
public interface IEnterpriseSettingsService
{
    /** 解析当前用户所属公司（未绑定默认公司1） */
    public Long resolveCompanyId(Long userId);

    /** 解析当前用户所属公司（未绑定直接报错，不回落默认公司） */
    public Long requireCompanyId(Long userId);

    public List<Map<String, Object>> listTemplates(Long companyId);

    public int saveTemplate(Long companyId, Long id, String title, String content, Integer channel, Integer status);

    public int removeTemplate(Long companyId, Long id);

    public Map<String, Object> deptOverview(Long companyId);

    public int saveDept(Long companyId, Long id, Long parentId, String deptName, String leader, Integer orderNum, Integer status);

    public void removeDept(Long companyId, Long id);

    public List<Map<String, Object>> listIntegrations(Long companyId);

    public int saveIntegration(Long companyId, String provider, Integer status, String configJson);

    public List<Map<String, Object>> listMembers(Long companyId);

    public int changeMemberRole(Long companyId, Long userId, Long roleId);

    public int changeMemberStatus(Long companyId, Long userId, boolean enabled);

    public Map<String, Object> inviteMember(Long companyId, String userName, String nickName, String email, String dept, Long roleId);

    /** 当前企业对外展示信息（求职者企业主页同源字段） */
    public Map<String, Object> companyInfo(Long companyId);

    /** 更新当前企业对外展示信息，返回最新企业信息 */
    public Map<String, Object> updateCompanyInfo(Long companyId, Map<String, Object> form);
}
