package com.ruoyi.web.controller.enterprise;

import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.enterprise.service.IEnterpriseResumeImportService;
import com.ruoyi.common.core.controller.BaseController;

/**
 * 企业端简历管理
 */
@RestController
@RequestMapping("/enterprise/resumes")
public class EnterpriseResumeController extends BaseController
{
    @Autowired
    private IEnterpriseResumeImportService resumeImportService;

    /**
     * 批量导入简历（PDF）：按手机号/邮箱匹配已注册候选人账号
     */
    @Log(title = "企业端简历批量导入", businessType = BusinessType.IMPORT, isSaveRequestData = false, isSaveResponseData = false)
    @PostMapping("/batch-import")
    public AjaxResult batchImport(@RequestParam("files") List<MultipartFile> files,
            @RequestParam(value = "deduplicate", defaultValue = "true") boolean deduplicate)
    {
        List<java.util.Map<String, Object>> results = resumeImportService.batchImport(getUserId(), files, deduplicate);
        AjaxResult result = success();
        result.put("data", results);
        return result;
    }
}
