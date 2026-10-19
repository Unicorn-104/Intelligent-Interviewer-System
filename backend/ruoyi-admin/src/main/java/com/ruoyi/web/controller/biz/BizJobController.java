package com.ruoyi.web.controller.biz;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.service.biz.IBizJobService;

/**
 * 平台运营 - 岗位监管 Controller（/biz/job）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/biz/job")
public class BizJobController extends BaseController
{
    @Autowired
    private IBizJobService jobService;

    /**
     * 平台岗位列表（跨企业分页）
     */
    @PreAuthorize("@ss.hasPermi('biz:job:query')")
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String jobName,
                              @RequestParam(required = false) String companyName,
                              @RequestParam(required = false) Integer status)
    {
        startPage();
        List<Map<String, Object>> list = jobService.selectAdminJobList(jobName, companyName, status);
        return getDataTable(list);
    }

    /**
     * 岗位审核：通过发布 / 违规下架
     */
    @PreAuthorize("@ss.hasPermi('biz:job:audit')")
    @Log(title = "岗位审核", businessType = BusinessType.UPDATE)
    @PutMapping("/audit")
    public AjaxResult audit(@RequestBody Map<String, Object> body)
    {
        Long posId = body.get("jobId") == null ? null : Long.valueOf(String.valueOf(body.get("jobId")));
        Integer result = body.get("result") == null ? null : Integer.valueOf(String.valueOf(body.get("result")));
        String reason = body.get("reason") == null ? null : String.valueOf(body.get("reason"));
        return toAjax(jobService.auditJob(posId, result, reason));
    }
}
