package com.ruoyi.web.controller.system;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.IEnterpriseSettingsService;

/**
 * 企业系统设置（通知模板/组织架构/面试集成/用户权限）
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/system/enterprise/settings")
public class EnterpriseSettingsController extends BaseController
{
    @Autowired
    private IEnterpriseSettingsService settingsService;

    private Long companyId()
    {
        return settingsService.resolveCompanyId(getUserId());
    }

    private Long asLong(Object v)
    {
        if (v == null)
        {
            return null;
        }
        if (v instanceof Number)
        {
            return ((Number) v).longValue();
        }
        String s = v.toString().trim();
        return s.isEmpty() ? null : Long.valueOf(s);
    }

    private Integer asInt(Object v)
    {
        Long l = asLong(v);
        return l == null ? null : l.intValue();
    }

    // ==================== 通知模板 ====================

    @GetMapping("/templates")
    public AjaxResult templates()
    {
        return success(settingsService.listTemplates(companyId()));
    }

    @PostMapping("/templates")
    public AjaxResult addTemplate(@RequestBody Map<String, Object> body)
    {
        settingsService.saveTemplate(companyId(), null, str(body, "title"), str(body, "content"),
                asInt(body.get("channel")), null);
        return success();
    }

    @PutMapping("/templates/{id}")
    public AjaxResult editTemplate(@PathVariable Long id, @RequestBody Map<String, Object> body)
    {
        settingsService.saveTemplate(companyId(), id, str(body, "title"), str(body, "content"),
                asInt(body.get("channel")), asInt(body.get("status")));
        return success();
    }

    @DeleteMapping("/templates/{id}")
    public AjaxResult removeTemplate(@PathVariable Long id)
    {
        return toAjax(settingsService.removeTemplate(companyId(), id));
    }

    // ==================== 组织架构 ====================

    @GetMapping("/depts")
    public AjaxResult depts()
    {
        return success(settingsService.deptOverview(companyId()));
    }

    @PostMapping("/depts")
    public AjaxResult addDept(@RequestBody Map<String, Object> body)
    {
        settingsService.saveDept(companyId(), null, asLong(body.get("parentId")), str(body, "name"),
                str(body, "leader"), asInt(body.get("orderNum")), null);
        return success();
    }

    @PutMapping("/depts/{id}")
    public AjaxResult editDept(@PathVariable Long id, @RequestBody Map<String, Object> body)
    {
        settingsService.saveDept(companyId(), id, asLong(body.get("parentId")), str(body, "name"),
                str(body, "leader"), asInt(body.get("orderNum")), asInt(body.get("status")));
        return success();
    }

    @DeleteMapping("/depts/{id}")
    public AjaxResult removeDept(@PathVariable Long id)
    {
        settingsService.removeDept(companyId(), id);
        return success();
    }

    // ==================== 面试集成 ====================

    @GetMapping("/integrations")
    public AjaxResult integrations()
    {
        return success(settingsService.listIntegrations(companyId()));
    }

    @PutMapping("/integrations/{provider}")
    public AjaxResult saveIntegration(@PathVariable String provider, @RequestBody Map<String, Object> body)
    {
        settingsService.saveIntegration(companyId(), provider, asInt(body.get("status")), str(body, "configJson"));
        return success();
    }

    // ==================== 用户权限 ====================

    @GetMapping("/members")
    public AjaxResult members()
    {
        return success(settingsService.listMembers(companyId()));
    }

    @PutMapping("/members/{userId}/role")
    public AjaxResult changeRole(@PathVariable Long userId, @RequestBody Map<String, Object> body)
    {
        return toAjax(settingsService.changeMemberRole(companyId(), userId, asLong(body.get("roleId"))));
    }

    @PutMapping("/members/{userId}/status")
    public AjaxResult changeStatus(@PathVariable Long userId, @RequestBody Map<String, Object> body)
    {
        boolean enabled = Boolean.TRUE.equals(body.get("enabled"));
        return toAjax(settingsService.changeMemberStatus(companyId(), userId, enabled));
    }

    @PostMapping("/members/invite")
    public AjaxResult invite(@RequestBody Map<String, Object> body)
    {
        Map<String, Object> result = settingsService.inviteMember(companyId(), str(body, "userName"),
                str(body, "nickName"), str(body, "email"), str(body, "dept"), asLong(body.get("roleId")));
        return success(result);
    }

    // ==================== 企业信息 ====================

    @GetMapping("/company")
    public AjaxResult company()
    {
        // 企业资料归属严格校验，未绑定账号不回落默认公司
        return success(settingsService.companyInfo(settingsService.requireCompanyId(getUserId())));
    }

    @PutMapping("/company")
    public AjaxResult saveCompany(@RequestBody Map<String, Object> body)
    {
        return success(settingsService.updateCompanyInfo(settingsService.requireCompanyId(getUserId()), body));
    }

    private String str(Map<String, Object> body, String key)
    {
        Object v = body.get(key);
        return v == null ? null : v.toString();
    }
}
