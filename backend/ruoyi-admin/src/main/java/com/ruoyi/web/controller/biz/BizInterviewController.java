package com.ruoyi.web.controller.biz;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
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
import com.ruoyi.system.service.biz.IBizInterviewService;

/**
 * 平台运营 - 面试会话监管 Controller（/biz/interview）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/biz/interview")
public class BizInterviewController extends BaseController
{
    @Autowired
    private IBizInterviewService interviewService;

    @PreAuthorize("@ss.hasPermi('biz:interview:query')")
    @GetMapping("/list")
    public TableDataInfo list()
    {
        startPage();
        List<Map<String, Object>> list = interviewService.selectAdminInterviewList();
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:interview:query')")
    @GetMapping("/{sesId}")
    public AjaxResult getInfo(@PathVariable("sesId") Long sesId)
    {
        return success(interviewService.selectAdminInterviewById(sesId));
    }

    @PreAuthorize("@ss.hasPermi('biz:interview:edit')")
    @Log(title = "强制结束面试", businessType = BusinessType.UPDATE)
    @PutMapping("/terminate")
    public AjaxResult terminate(@RequestBody Map<String, Object> body)
    {
        Long sesId = body.get("interviewId") == null ? null : Long.valueOf(String.valueOf(body.get("interviewId")));
        String reason = body.get("reason") == null ? null : String.valueOf(body.get("reason"));
        return toAjax(interviewService.terminateInterview(sesId, reason));
    }

    @PreAuthorize("@ss.hasPermi('biz:interview:remove')")
    @Log(title = "面试会话", businessType = BusinessType.DELETE)
    @DeleteMapping("/{sesId}")
    public AjaxResult remove(@PathVariable Long sesId)
    {
        // 降级：平台端仅支持强制结束，不物理删除会话
        return AjaxResult.error("平台端不支持删除面试会话，请使用强制结束");
    }
}
