package com.ruoyi.web.controller.enterprise;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.ITalentPoolService;
import com.ruoyi.system.domain.app.AppResumePdfDocument;

/**
 * 企业端 - 人才库
 *
 * <p>依据《业务功能分析》UC-03（人才库简历检索与管理）：
 * 结构化人才数据入库后供检索与复用；
 * UC-02（简历投递与智能解析）步骤4-5：智能字段提取 +
 * 完整度检查（标记缺失字段）。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/talent")
public class TalentPoolController extends BaseController
{
    @Autowired
    private ITalentPoolService talentPoolService;

    /**
     * UC-03：人才库检索（关键词/标签/岗位方向/归档来源 + 分页）
     */
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String keyword,
            @RequestParam(required = false) String tag,
            @RequestParam(required = false) String direction,
            @RequestParam(required = false) Integer archiveSource,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize,
            @ModelAttribute TalentSearchCriteria criteria)
    {
        return getDataTable(talentPoolService.listTalents(getUserId(), keyword, tag, direction, archiveSource,
                status, pageNum, pageSize, criteria));
    }

    /**
     * 候选人列表：一条投递一行（岗位 + 投递状态 + Offer 状态 + 当前流程阶段）
     */
    @GetMapping("/applications")
    public TableDataInfo applications(@RequestParam(required = false) Long positionId,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(talentPoolService.listApplications(getUserId(), positionId, status,
                pageNum, pageSize));
    }

    /**
     * 候选人列表的岗位下拉选项（本企业有过投递的岗位，去重）
     */
    @GetMapping("/applications/positions")
    public AjaxResult applicationPositions()
    {
        return success(talentPoolService.listApplicationPositions(getUserId()));
    }

    /**
     * 批量更新投递状态（按投递维度，不再影响同一候选人的其他岗位）
     */
    @PutMapping("/applications/status")
    public AjaxResult updateApplicationStatus(@RequestBody Map<String, Object> body)
    {
        List<Long> applicationIds = new ArrayList<>();
        Object raw = body.get("applicationIds");
        if (raw instanceof List)
        {
            for (Object item : (List<?>) raw)
            {
                if (item != null)
                {
                    applicationIds.add(Long.valueOf(String.valueOf(item)));
                }
            }
        }
        Integer status = body.get("status") == null ? null
                : Integer.valueOf(String.valueOf(body.get("status")));
        return success(talentPoolService.updateApplicationStatus(getUserId(), applicationIds, status));
    }

    /**
     * UC-03：人才库筛选项（岗位方向 + 标签）
     */
    @GetMapping("/options")
    public AjaxResult options()
    {
        return success(talentPoolService.getTalentOptions(getUserId()));
    }

    /**
     * 待初筛：各岗位尚未经过 AI 初筛的投递数量
     */
    @GetMapping("/unscreened/positions")
    public AjaxResult unscreenedPositions()
    {
        return success(talentPoolService.getUnscreenedPositions(getUserId()));
    }

    /**
     * 待初筛：投递人选列表（岗位/关键词 + 分页）
     */
    @GetMapping("/unscreened/applicants")
    public TableDataInfo unscreenedApplicants(@RequestParam(required = false) Long positionId,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize)
    {
        return getDataTable(talentPoolService.listUnscreenedApplicants(getUserId(), positionId, keyword,
                pageNum, pageSize));
    }

    /**
     * 待初筛：对指定岗位的待初筛投递发起 AI 初筛
     */
    @PostMapping("/unscreened/screen")
    public AjaxResult screenUnscreened(@RequestBody Map<String, Object> body)
    {
        Long positionId = body.get("positionId") == null ? null
                : Long.valueOf(String.valueOf(body.get("positionId")));
        return success(talentPoolService.screenUnscreenedPosition(getUserId(), positionId));
    }

    /**
     * UC-03：主动归档 / 取消归档
     */
    @PutMapping("/{talId}/archive")
    public AjaxResult archive(@PathVariable("talId") Long talId, @RequestBody Map<String, Object> body)
    {
        Boolean archived = body.get("archived") == null ? Boolean.TRUE
                : Boolean.valueOf(String.valueOf(body.get("archived")));
        return success(talentPoolService.archiveTalent(getUserId(), talId, archived));
    }

    /**
     * UC-03：批量更新候选人流程状态（候选人管理的状态管理）
     */
    @PutMapping("/status")
    public AjaxResult updateStatus(@RequestBody Map<String, Object> body)
    {
        List<Long> talIds = new ArrayList<>();
        Object raw = body.get("talIds");
        if (raw instanceof List)
        {
            for (Object item : (List<?>) raw)
            {
                if (item != null)
                {
                    talIds.add(Long.valueOf(String.valueOf(item)));
                }
            }
        }
        Integer status = body.get("status") == null ? null
                : Integer.valueOf(String.valueOf(body.get("status")));
        return success(talentPoolService.updateStatus(getUserId(), talIds, status));
    }

    /**
     * UC-03：批量为候选人添加标签
     */
    @PostMapping("/tags/batch")
    public AjaxResult batchTags(@RequestBody Map<String, Object> body)
    {
        List<Long> talIds = new ArrayList<>();
        Object raw = body.get("talIds");
        if (raw instanceof List)
        {
            for (Object item : (List<?>) raw)
            {
                if (item != null)
                {
                    talIds.add(Long.valueOf(String.valueOf(item)));
                }
            }
        }
        String tagName = body.get("tagName") == null ? null : String.valueOf(body.get("tagName"));
        Integer source = body.get("source") == null ? 1 : Integer.valueOf(String.valueOf(body.get("source")));
        return success(talentPoolService.batchTags(getUserId(), talIds, tagName, source));
    }

    /**
     * UC-03：一键转投递（为候选人创建投递记录）
     */
    @PostMapping("/{talId}/reapply")
    public AjaxResult reapply(@PathVariable("talId") Long talId, @RequestBody Map<String, Object> body)
    {
        Long positionId = body.get("positionId") == null ? null
                : Long.valueOf(String.valueOf(body.get("positionId")));
        return success(talentPoolService.reapplyTalent(getUserId(), talId, positionId));
    }

    /**
     * UC-03：落选关怀通知（批量写入系统消息）
     */
    @PostMapping("/care-notify")
    public AjaxResult careNotify(@RequestBody Map<String, Object> body)
    {
        List<Long> talIds = new ArrayList<>();
        Object raw = body.get("talIds");
        if (raw instanceof List)
        {
            for (Object item : (List<?>) raw)
            {
                if (item != null)
                {
                    talIds.add(Long.valueOf(String.valueOf(item)));
                }
            }
        }
        String title = body.get("title") == null ? null : String.valueOf(body.get("title"));
        String content = body.get("content") == null ? null : String.valueOf(body.get("content"));
        return success(talentPoolService.careNotify(getUserId(), talIds, title, content));
    }

    /**
     * UC-03：候选人详情
     */
    @GetMapping("/{talId}")
    public AjaxResult detail(@PathVariable("talId") Long talId)
    {
        return success(talentPoolService.getTalentDetail(getUserId(), talId));
    }

    /**
     * UC-02/UC-03：简历智能解析结果（结构化字段 + 完整度检查标记）
     */
    @GetMapping("/{talId}/resume")
    public AjaxResult resume(@PathVariable("talId") Long talId)
    {
        return success(talentPoolService.getTalentResume(getUserId(), talId));
    }

    /**
     * 查看候选人原始简历 PDF（校验候选人归属本企业后内联预览，仅 Bearer 鉴权可访问）
     */
    @GetMapping("/{talId}/resume/pdf")
    public ResponseEntity<Resource> resumePdf(@PathVariable("talId") Long talId)
    {
        AppResumePdfDocument document = talentPoolService.getTalentResumePdf(getUserId(), talId);
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(document.name() == null ? "resume.pdf" : document.name(),
                                StandardCharsets.UTF_8).build().toString())
                .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
                .header("X-Content-Type-Options", "nosniff")
                .body(new FileSystemResource(document.path()));
    }
}
