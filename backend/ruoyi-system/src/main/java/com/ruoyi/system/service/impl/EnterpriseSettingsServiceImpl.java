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
    public Long requireCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        if (companyId == null)
        {
            throw new ServiceException("请先完成企业绑定", 403);
        }
        return companyId;
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

    @Override
    public Map<String, Object> companyInfo(Long companyId)
    {
        Map<String, Object> company = settingsMapper.selectOwnCompany(companyId);
        if (company == null)
        {
            throw new ServiceException("企业信息不存在，请先完成企业绑定");
        }
        return company;
    }

    @Override
    @Transactional
    public Map<String, Object> updateCompanyInfo(Long companyId, Map<String, Object> form)
    {
        if (form == null)
        {
            throw new ServiceException("请填写企业信息");
        }
        String name = cleanField(form.get("name"), 100);
        if (StringUtils.isEmpty(name))
        {
            throw new ServiceException("企业名称不能为空");
        }
        String industry = cleanField(form.get("industry"), 50);
        String size = cleanField(form.get("size"), 20);
        String city = cleanField(form.get("city"), 50);
        String address = cleanField(form.get("address"), 200);
        String website = cleanField(form.get("website"), 255);
        String intro = cleanField(form.get("intro"), 4000);
        String logoUrl = cleanField(form.get("logoUrl"), 255);
        if (settingsMapper.selectOwnCompany(companyId) == null)
        {
            throw new ServiceException("企业信息不存在，请先完成企业绑定");
        }
        try
        {
            if (settingsMapper.updateOwnCompany(companyId, name, industry, size, city, address, website, intro, logoUrl) != 1)
            {
                throw new ServiceException("企业信息保存失败，请稍后重试");
            }
        }
        catch (org.springframework.dao.DataIntegrityViolationException e)
        {
            throw new ServiceException("企业名称已被使用或内容不合法，请核对后重试");
        }
        return companyInfo(companyId);
    }

    private String cleanField(Object value, int maxLength)
    {
        if (value == null)
        {
            return null;
        }
        String text = value.toString().trim();
        if (text.isEmpty())
        {
            return null;
        }
        if (text.length() > maxLength)
        {
            throw new ServiceException("字段长度超过限制（" + maxLength + " 字）");
        }
        return text;
    }
}
