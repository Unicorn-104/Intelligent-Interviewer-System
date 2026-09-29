package com.ruoyi.system.service.impl;

import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.EnterpriseSettingsMapper;
import com.ruoyi.system.service.IEnterpriseSettingsService;

/**
 * 企业系统设置 服务实现
 *
 * @author ruoyi
 */
@Service
public class EnterpriseSettingsServiceImpl implements IEnterpriseSettingsService
{
    @Autowired
    private EnterpriseSettingsMapper settingsMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Override
    public Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }

    @Override
    public List<Map<String, Object>> listTemplates(Long companyId)
    {
        return settingsMapper.selectTemplates(companyId);
    }

    @Override
    public int saveTemplate(Long companyId, Long id, String title, String content, Integer channel, Integer status)
    {
        if (StringUtils.isEmpty(title) || StringUtils.isEmpty(content))
        {
            throw new ServiceException("模板标题与内容不能为空");
        }
        if (id == null)
        {
            String code = "custom_" + new Date().getTime();
            return settingsMapper.insertTemplate(companyId, code, title, content, channel == null ? 1 : channel);
        }
        return settingsMapper.updateTemplate(id, companyId, title, content, channel == null ? 1 : channel, status == null ? 1 : status);
    }

    @Override
    public int removeTemplate(Long companyId, Long id)
    {
        return settingsMapper.deleteTemplate(id, companyId);
    }

    @Override
    public Map<String, Object> deptOverview(Long companyId)
    {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("depts", settingsMapper.selectDepts(companyId));
        result.put("deptCount", settingsMapper.countDepts(companyId));
        result.put("memberCount", settingsMapper.countMembers(companyId));
        result.put("positionCount", settingsMapper.countActivePositions(companyId));
        return result;
    }

    @Override
    public int saveDept(Long companyId, Long id, Long parentId, String deptName, String leader, Integer orderNum, Integer status)
    {
        if (StringUtils.isEmpty(deptName))
        {
            throw new ServiceException("部门名称不能为空");
        }
        if (id == null)
        {
            return settingsMapper.insertDept(companyId, parentId == null ? 0L : parentId, deptName, leader, orderNum == null ? 0 : orderNum);
        }
        return settingsMapper.updateDept(id, companyId, deptName, leader, orderNum == null ? 0 : orderNum, status == null ? 1 : status);
    }

    @Override
    public void removeDept(Long companyId, Long id)
    {
        if (settingsMapper.countDeptChildren(id) > 0)
        {
            throw new ServiceException("该部门存在子部门，请先删除子部门");
        }
        if (settingsMapper.countDeptMembers(id, companyId) > 0)
        {
            throw new ServiceException("该部门下仍有成员，无法删除");
        }
        settingsMapper.deleteDept(id, companyId);
    }

    @Override
    public List<Map<String, Object>> listIntegrations(Long companyId)
    {
        return settingsMapper.selectIntegrations(companyId);
    }

    @Override
    public int saveIntegration(Long companyId, String provider, Integer status, String configJson)
    {
        return settingsMapper.updateIntegration(companyId, provider, status, configJson);
    }

    @Override
    public List<Map<String, Object>> listMembers(Long companyId)
    {
        return settingsMapper.selectMembers(companyId);
    }

    @Override
    @Transactional
    public int changeMemberRole(Long companyId, Long userId, Long roleId)
    {
        if (roleId == null || roleId < 101L || roleId > 103L)
        {
            throw new ServiceException("非法角色");
        }
        settingsMapper.deleteUserBizRoles(userId);
        return settingsMapper.insertUserRole(userId, roleId);
    }

    @Override
    public int changeMemberStatus(Long companyId, Long userId, boolean enabled)
    {
        return settingsMapper.updateUserStatus(userId, companyId, enabled ? "0" : "1");
    }

    @Override
    @Transactional
    public Map<String, Object> inviteMember(Long companyId, String userName, String nickName, String email, String dept, Long roleId)
    {
        if (StringUtils.isEmpty(userName) || StringUtils.isEmpty(nickName))
        {
            throw new ServiceException("登录账号与姓名不能为空");
        }
        if (settingsMapper.selectUserIdByName(userName) != null)
        {
            throw new ServiceException("登录账号已存在");
        }
        String initPassword = "Recruit@" + (int) ((Math.random() * 9 + 1) * 100000);
        settingsMapper.insertUser(userName, nickName, email, SecurityUtils.encryptPassword(initPassword));
        Long userId = settingsMapper.selectUserIdByName(userName);
        settingsMapper.insertBinding(userId, companyId, StringUtils.isEmpty(dept) ? "未分配" : dept);
        settingsMapper.insertUserRole(userId, roleId == null ? 102L : roleId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("userId", userId);
        result.put("initPassword", initPassword);
        return result;
    }
}
