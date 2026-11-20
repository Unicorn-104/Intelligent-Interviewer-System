package com.ruoyi.web.controller.enterprise;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.system.service.IEnterpriseRegisterService;

/**
 * 企业账号状态
 *
 * @author ruoyi
 */
@RestController
@RequestMapping("/enterprise/account")
public class EnterpriseAccountController extends BaseController
{
    @Autowired
    private IEnterpriseRegisterService enterpriseRegisterService;

    /**
     * 当前账号的企业绑定与审核状态
     */
    @GetMapping("/status")
    public AjaxResult status()
    {
        return success(enterpriseRegisterService.accountStatus(getUserId()));
    }
}
