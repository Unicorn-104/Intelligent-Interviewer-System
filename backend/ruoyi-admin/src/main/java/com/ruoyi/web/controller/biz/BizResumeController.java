package com.ruoyi.web.controller.biz;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.system.service.biz.IBizResumeService;

/**
 * 平台运营 - 简历库 Controller（/biz/resume，降级实现）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/biz/resume")
public class BizResumeController extends BaseController
{
    @Autowired
    private IBizResumeService resumeService;

    @PreAuthorize("@ss.hasPermi('biz:resume:query')")
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String name,
                              @RequestParam(required = false) String jobName,
                              @RequestParam(required = false) String source)
    {
        startPage();
        List<Map<String, Object>> list = resumeService.selectAdminResumeList(name, jobName, source);
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:resume:query')")
    @GetMapping("/{rbsId}")
    public AjaxResult getInfo(@PathVariable("rbsId") Long rbsId)
    {
        return success(resumeService.selectAdminResumeById(rbsId));
    }

    @PreAuthorize("@ss.hasPermi('biz:resume:remove')")
    @Log(title = "简历库", businessType = BusinessType.DELETE)
    @DeleteMapping("/{rbsIds}")
    public AjaxResult remove(@PathVariable Long[] rbsIds)
    {
        return toAjax(resumeService.deleteResumeByIds(rbsIds));
    }

    /**
     * 下载：降级实现，平台侧暂不提供跨用户 PDF 直取
     */
    @PreAuthorize("@ss.hasPermi('biz:resume:query')")
    @GetMapping("/download/{rbsId}")
    public AjaxResult download(@PathVariable("rbsId") Long rbsId)
    {
        return AjaxResult.error("简历原始文件暂不支持平台端下载");
    }
}
