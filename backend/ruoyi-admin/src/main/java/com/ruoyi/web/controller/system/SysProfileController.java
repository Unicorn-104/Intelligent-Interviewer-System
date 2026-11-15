package com.ruoyi.web.controller.system;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.framework.web.service.TokenService;
import com.ruoyi.enterprise.domain.NoticePref;
import com.ruoyi.enterprise.service.UserNoticePrefService;
import com.ruoyi.system.domain.SysLogininfor;
import com.ruoyi.system.service.ISysLogininforService;
import com.ruoyi.system.service.ISysUserService;
import com.ruoyi.system.service.storage.AvatarStorage;

/**
 * 个人信息 业务处理
 * 
 * @author ruoyi
 */
@RestController
@RequestMapping("/system/user/profile")
public class SysProfileController extends BaseController
{
    @Autowired
    private ISysUserService userService;

    @Autowired
    private TokenService tokenService;

    @Autowired
    private AvatarStorage avatarStorage;

    @Autowired
    private ISysLogininforService logininforService;

    @Autowired
    private UserNoticePrefService noticePrefService;

    /**
     * 本人通知设置
     */
    @GetMapping("/noticePref")
    public AjaxResult noticePref()
    {
        return success(noticePrefService.get(getUserId()));
    }

    /**
     * 保存本人通知设置
     */
    @Log(title = "通知设置", businessType = BusinessType.UPDATE)
    @PutMapping("/noticePref")
    public AjaxResult updateNoticePref(@RequestBody NoticePref pref)
    {
        noticePrefService.save(getUserId(), pref);
        return success();
    }

    /**
     * 本人最近登录记录
     */
    @GetMapping("/loginRecords")
    public AjaxResult loginRecords()
    {
        String userName = getUsername();
        SysLogininfor query = new SysLogininfor();
        query.setUserName(userName);
        List<SysLogininfor> records = logininforService.selectLogininforList(query).stream()
                .filter(item -> userName.equals(item.getUserName()))
                .limit(10)
                .collect(Collectors.toList());
        return success(records);
    }

    /**
     * 个人信息
     */
    @GetMapping
    public AjaxResult profile()
    {
        LoginUser loginUser = getLoginUser();
        SysUser user = loginUser.getUser();
        AjaxResult ajax = AjaxResult.success(user);
        ajax.put("roleGroup", userService.selectUserRoleGroup(loginUser.getUsername()));
        ajax.put("postGroup", userService.selectUserPostGroup(loginUser.getUsername()));
        return ajax;
    }

    /**
     * 修改用户
     */
    @Log(title = "个人信息", businessType = BusinessType.UPDATE)
    @PutMapping
    public AjaxResult updateProfile(@RequestBody SysUser user)
    {
        LoginUser loginUser = getLoginUser();
        SysUser currentUser = loginUser.getUser();
        currentUser.setNickName(user.getNickName());
        currentUser.setEmail(user.getEmail());
        currentUser.setPhonenumber(user.getPhonenumber());
        currentUser.setSex(user.getSex());
        currentUser.setRemark(user.getRemark());
        if (StringUtils.isNotEmpty(user.getPhonenumber()) && !userService.checkPhoneUnique(currentUser))
        {
            return error("修改用户'" + loginUser.getUsername() + "'失败，手机号码已存在");
        }
        if (StringUtils.isNotEmpty(user.getEmail()) && !userService.checkEmailUnique(currentUser))
        {
            return error("修改用户'" + loginUser.getUsername() + "'失败，邮箱账号已存在");
        }
        if (userService.updateUserProfile(currentUser) > 0)
        {
            // 更新缓存用户信息
            tokenService.setLoginUser(loginUser);
            return success();
        }
        return error("修改个人信息异常，请联系管理员");
    }

    /**
     * 重置密码
     */
    @Log(title = "个人信息", businessType = BusinessType.UPDATE)
    @PutMapping("/updatePwd")
    public AjaxResult updatePwd(@RequestBody Map<String, String> params)
    {
        String oldPassword = params.get("oldPassword");
        String newPassword = params.get("newPassword");
        LoginUser loginUser = getLoginUser();
        Long userId = loginUser.getUserId();
        SysUser user = userService.selectUserById(userId);
        String password = user.getPassword();
        if (!SecurityUtils.matchesPassword(oldPassword, password))
        {
            return error("修改密码失败，旧密码错误");
        }
        if (SecurityUtils.matchesPassword(newPassword, password))
        {
            return error("新密码不能与旧密码相同");
        }
        newPassword = SecurityUtils.encryptPassword(newPassword);
        if (userService.resetUserPwd(userId, newPassword) > 0)
        {
            // 更新缓存用户密码&密码最后更新时间
            loginUser.getUser().setPwdUpdateDate(DateUtils.getNowDate());
            loginUser.getUser().setPassword(newPassword);
            tokenService.setLoginUser(loginUser);
            // 密码变更后仅失效其它端的登录会话与刷新令牌，保留当前会话继续使用
            tokenService.clearOtherSessions(userId, loginUser.getToken());
            return success();
        }
        return error("修改密码异常，请联系管理员");
    }

    /**
     * 头像上传
     */
    @Log(title = "用户头像", businessType = BusinessType.UPDATE)
    @PostMapping("/avatar")
    public AjaxResult avatar(@RequestParam("avatarfile") MultipartFile file) throws Exception
    {
        if (file != null && !file.isEmpty())
        {
            LoginUser loginUser = getLoginUser();
            String oldAvatar = loginUser.getUser().getAvatar();
            String avatar = avatarStorage.store(loginUser.getUserId(), file);
            if (userService.updateUserAvatar(loginUser.getUserId(), avatar))
            {
                AjaxResult ajax = AjaxResult.success();
                ajax.put("imgUrl", avatar);
                // 更新缓存用户头像
                loginUser.getUser().setAvatar(avatar);
                tokenService.setLoginUser(loginUser);
                avatarStorage.delete(loginUser.getUserId(), oldAvatar);
                return ajax;
            }
            // 只有数据库明确拒绝更新时清理新文件；异常/超时的提交状态未知，不盲删。
            avatarStorage.delete(loginUser.getUserId(), avatar);
        }
        return error("上传图片异常，请联系管理员");
    }
}
