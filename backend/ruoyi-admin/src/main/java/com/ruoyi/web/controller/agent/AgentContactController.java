package com.ruoyi.web.controller.agent;

import java.util.Map;
import jakarta.validation.constraints.Positive;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.app.AppCompanyMapper;

@Validated
@RestController
@RequestMapping("/agent/v1/contacts")
public class AgentContactController extends BaseController
{
    @Autowired private AppCompanyMapper companies;

    @GetMapping("/{contactId}")
    public AjaxResult detail(@PathVariable @Positive Long contactId)
    {
        getUserId();
        Map<String, Object> contact = companies.selectRecruiter(contactId);
        if (contact == null || contact.isEmpty()) throw new ServiceException("招聘联系人不存在或企业已下架", 404);
        return success(contact);
    }
}
