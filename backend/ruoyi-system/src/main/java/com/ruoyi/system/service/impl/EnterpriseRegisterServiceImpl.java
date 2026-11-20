package com.ruoyi.system.service.impl;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.core.domain.entity.SysRole;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.Company;
import com.ruoyi.system.mapper.CompanyMapper;
import com.ruoyi.system.mapper.SysRoleMapper;
import com.ruoyi.system.service.IEnterpriseRegisterService;
import com.ruoyi.system.service.ISysUserService;

/**
 * 企业自助注册服务实现
 *
 * @author ruoyi
 */
@Service
public class EnterpriseRegisterServiceImpl implements IEnterpriseRegisterService
{
    private static final Pattern PHONE_PATTERN = Pattern.compile("^1[3-9]\\d{9}$");

    /** 企业超级管理员角色标识 */
    private static final String ENTERPRISE_ADMIN_ROLE = "biz_1";

    @Autowired
    private CompanyMapper companyMapper;

    @Autowired
    private ISysUserService userService;

    @Autowired
    private SysRoleMapper roleMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void register(Map<String, Object> body)
    {
        String username = trim(str(body, "username"));
        String password = str(body, "password");
        String companyName = trim(str(body, "companyName"));
        String contactName = trim(str(body, "contactName"));
        String phone = trim(str(body, "phone"));
        String email = trim(str(body, "email"));
        String creditCode = trim(str(body, "creditCode"));
        String industry = trim(str(body, "industry"));
        String city = trim(str(body, "city"));
        String companySize = trim(str(body, "companySize"));

        if (StringUtils.isEmpty(username) || username.length() < 2 || username.length() > 20)
        {
            throw new ServiceException("账号长度必须在2到20个字符之间");
        }
        if (StringUtils.isEmpty(password) || password.length() < 5 || password.length() > 20)
        {
            throw new ServiceException("密码长度必须在5到20个字符之间");
        }
        if (StringUtils.isEmpty(companyName))
        {
            throw new ServiceException("企业名称不能为空");
        }
        if (StringUtils.isEmpty(contactName))
        {
            throw new ServiceException("联系人不能为空");
        }
        if (StringUtils.isEmpty(phone) || !PHONE_PATTERN.matcher(phone).matches())
        {
            throw new ServiceException("请输入正确的手机号");
        }
        if (companyMapper.selectCompanyByNameExact(companyName) != null)
        {
            throw new ServiceException("该企业名称已注册，请联系平台管理员");
        }

        SysUser user = new SysUser();
        user.setUserName(username);
        user.setPhonenumber(phone);
        if (!userService.checkUserNameUnique(user))
        {
            throw new ServiceException("账号已存在");
        }
        if (!userService.checkPhoneUnique(user))
        {
            throw new ServiceException("该手机号已注册");
        }

        SysRole enterpriseRole = roleMapper.checkRoleKeyUnique(ENTERPRISE_ADMIN_ROLE);
        if (enterpriseRole == null)
        {
            throw new ServiceException("注册失败，系统未配置企业管理员角色");
        }

        Company company = new Company();
        company.setCmpName(companyName);
        company.setCmpCreditCode(emptyToNull(creditCode));
        company.setCmpIndustry(emptyToNull(industry));
        company.setCmpCity(emptyToNull(city));
        company.setCmpSize(emptyToNull(companySize));
        company.setContactName(contactName);
        company.setContactPhone(phone);
        company.setCmpVerifyStatus(0);
        company.setCmpStatus(1);
        company.setCmpCreatedAt(DateUtils.getNowDate());
        companyMapper.insertCompany(company);

        user.setNickName(contactName);
        user.setEmail(emptyToNull(email));
        user.setUserIdentityType(2);
        user.setStatus("0");
        user.setPwdUpdateDate(DateUtils.getNowDate());
        user.setPassword(SecurityUtils.encryptPassword(password));
        if (!userService.registerUser(user))
        {
            throw new ServiceException("注册失败，请联系系统管理人员");
        }

        companyMapper.updateUserCompanyId(user.getUserId(), company.getCmpId());
        companyMapper.insertEnterpriseBinding(user.getUserId(), company.getCmpId(), "企业管理员", 0);
        userService.insertUserAuth(user.getUserId(), new Long[] { enterpriseRole.getRoleId() });
    }

    @Override
    public Map<String, Object> accountStatus(Long userId)
    {
        Map<String, Object> status = companyMapper.selectBindingStatusByUser(userId);
        if (status == null)
        {
            status = new LinkedHashMap<>();
            status.put("companyId", null);
            status.put("companyName", null);
            status.put("bindingStatus", null);
            status.put("companyVerifyStatus", null);
            status.put("rejectReason", null);
        }
        return status;
    }

    private String str(Map<String, Object> body, String key)
    {
        Object value = body == null ? null : body.get(key);
        return value == null ? null : value.toString();
    }

    private String trim(String value)
    {
        return value == null ? null : value.trim();
    }

    private String emptyToNull(String value)
    {
        return StringUtils.isEmpty(value) ? null : value;
    }
}
