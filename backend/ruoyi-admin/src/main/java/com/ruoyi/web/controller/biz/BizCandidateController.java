package com.ruoyi.web.controller.biz;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
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

    /** 统计概览 */
    @PreAuthorize("@ss.hasPermi('biz:candidate:query')")
    @GetMapping("/summary")
    public AjaxResult summary()
    {
        return success(candidateService.selectCandidateSummary());
    }

    @PreAuthorize("@ss.hasPermi('biz:candidate:query')")
    @GetMapping("/{talId}")
    public AjaxResult getInfo(@PathVariable("talId") Long talId)
    {
        return success(candidateService.selectAdminCandidateById(talId));
    }

    /** 状态变更历史 */
    @PreAuthorize("@ss.hasPermi('biz:candidate:query')")
    @GetMapping("/{talId}/logs")
    public AjaxResult logs(@PathVariable("talId") Long talId)
    {
        return success(candidateService.selectTalStatusLogs(talId));
    }

    @PreAuthorize("@ss.hasPermi('biz:candidate:edit')")
    @Log(title = "候选人状态", businessType = BusinessType.UPDATE)
    @PutMapping("/status")
    public AjaxResult updateStatus(@RequestBody Map<String, Object> body)
    {
        Long talId = body.get("candidateId") == null ? null : Long.valueOf(String.valueOf(body.get("candidateId")));
        Integer status = toInt(body.get("status"));
        String reason = body.get("reason") == null ? null : String.valueOf(body.get("reason"));
        return toAjax(candidateService.updateCandidateStatus(talId, status, reason, getUserId()));
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

    /** 批量给多个候选人打标签 */
    @PreAuthorize("@ss.hasPermi('biz:candidate:edit')")
    @Log(title = "批量打标签", businessType = BusinessType.UPDATE)
    @PutMapping("/batchTags")
    public AjaxResult batchTags(@RequestBody Map<String, Object> body)
    {
        List<Long> ids = Arrays.stream(String.valueOf(body.get("ids")).split(","))
                .map(String::trim).filter(s -> !s.isEmpty()).map(Long::valueOf)
                .collect(Collectors.toList());
        String tags = body.get("tags") == null ? null : String.valueOf(body.get("tags"));
        return toAjax(candidateService.batchUpdateTags(ids, tags));
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
