package com.ruoyi.web.controller.biz;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.service.biz.IBizExamService;

/**
 * 平台运营 - 考核环境配置与记录 Controller（/biz/exam）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/biz/exam")
public class BizExamController extends BaseController
{
    @Autowired
    private IBizExamService examService;

    @PreAuthorize("@ss.hasPermi('biz:exam:query')")
    @GetMapping("/config")
    public AjaxResult getConfig()
    {
        return success(examService.getConfig());
    }

    @PreAuthorize("@ss.hasPermi('biz:exam:edit')")
    @Log(title = "考核环境配置", businessType = BusinessType.UPDATE)
    @PutMapping("/config")
    public AjaxResult saveConfig(@RequestBody Map<String, Object> body)
    {
        examService.saveConfig(body);
        return success();
    }

    @PreAuthorize("@ss.hasPermi('biz:exam:query')")
    @GetMapping("/record/list")
    public TableDataInfo recordList()
    {
        List<Map<String, Object>> list = examService.listRecords();
        return getDataTable(list);
    }
}
