package com.ruoyi.web.controller.system;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.domain.UserVerify;
import com.ruoyi.system.service.IUserVerifyService;

/**
 * 用户实名认证审核Controller（管理员端）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/system/userVerify")
public class UserVerifyController extends BaseController
{
    @Autowired
    private IUserVerifyService userVerifyService;

    /**
     * 查询实名认证列表
     */
    @PreAuthorize("@ss.hasPermi('system:userVerify:list')")
    @GetMapping("/list")
    public TableDataInfo list(UserVerify userVerify)
    {
        startPage();
        List<UserVerify> list = userVerifyService.selectUserVerifyList(userVerify);
        return getDataTable(list);
    }

    /**
     * 获取实名认证详细信息
     */
    @PreAuthorize("@ss.hasPermi('system:userVerify:query')")
    @GetMapping(value = "/{vefId}")
    public AjaxResult getInfo(@PathVariable("vefId") Long vefId)
    {
        return success(userVerifyService.selectUserVerifyByVefId(vefId));
    }

    /**
     * 审核实名认证：通过或拒绝
     */
    @PreAuthorize("@ss.hasPermi('system:userVerify:verify')")
    @Log(title = "实名认证审核", businessType = BusinessType.UPDATE)
    @PutMapping("/verify/{vefId}/{vefStatus}")
    public AjaxResult verify(@PathVariable("vefId") Long vefId,
                             @PathVariable("vefStatus") Integer vefStatus,
                             @RequestBody(required = false) String rejectReason)
    {
        return toAjax(userVerifyService.verifyUser(vefId, vefStatus, rejectReason));
    }
}
