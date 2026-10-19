package com.ruoyi.web.controller.biz;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
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
import com.ruoyi.system.service.biz.IBizCandidateService;

/**
 * 平台运营 - 候选人监管 Controller（/biz/candidate）
 *
 * @author TQY
 */
@RestController
@RequestMapping("/biz/candidate")
public class BizCandidateController extends BaseController
{
    @Autowired
    private IBizCandidateService candidateService;

    @PreAuthorize("@ss.hasPermi('biz:candidate:query')")
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String userName,
                              @RequestParam(required = false) String status,
                              @RequestParam(required = false) String tags)
    {
        startPage();
        List<Map<String, Object>> list = candidateService.selectAdminCandidateList(userName, status, tags);
        return getDataTable(list);
    }

    @PreAuthorize("@ss.hasPermi('biz:candidate:query')")
    @GetMapping("/{talId}")
    public AjaxResult getInfo(@PathVariable("talId") Long talId)
    {
        return success(candidateService.selectAdminCandidateById(talId));
    }

    @PreAuthorize("@ss.hasPermi('biz:candidate:edit')")
    @Log(title = "候选人状态", businessType = BusinessType.UPDATE)
    @PutMapping("/status")
    public AjaxResult updateStatus(@RequestBody Map<String, Object> body)
    {
        Long talId = body.get("candidateId") == null ? null : Long.valueOf(String.valueOf(body.get("candidateId")));
        Integer status = toInt(body.get("status"));
        return toAjax(candidateService.updateCandidateStatus(talId, status));
    }

    @PreAuthorize("@ss.hasPermi('biz:candidate:edit')")
    @Log(title = "候选人标签", businessType = BusinessType.UPDATE)
    @PostMapping("/tag")
    public AjaxResult addTag(@RequestBody Map<String, Object> body)
    {
        Long talId = body.get("candidateId") == null ? null : Long.valueOf(String.valueOf(body.get("candidateId")));
        String tags = body.get("tags") == null ? null : String.valueOf(body.get("tags"));
        return toAjax(candidateService.batchUpdateTag(talId, tags, null));
    }

    @PreAuthorize("@ss.hasPermi('biz:candidate:edit')")
    @Log(title = "候选人标签", businessType = BusinessType.UPDATE)
    @PutMapping("/batchTag")
    public AjaxResult batchTag(@RequestBody Map<String, Object> body)
    {
        Long talId = body.get("candidateId") == null ? null : Long.valueOf(String.valueOf(body.get("candidateId")));
        String tags = body.get("tags") == null ? null : String.valueOf(body.get("tags"));
        String remark = body.get("remark") == null ? null : String.valueOf(body.get("remark"));
        return toAjax(candidateService.batchUpdateTag(talId, tags, remark));
    }

    private Integer toInt(Object v)
    {
        if (v == null)
        {
            return null;
        }
        try
        {
            return Integer.valueOf(String.valueOf(v));
        }
        catch (NumberFormatException e)
        {
            return null;
        }
    }
}
