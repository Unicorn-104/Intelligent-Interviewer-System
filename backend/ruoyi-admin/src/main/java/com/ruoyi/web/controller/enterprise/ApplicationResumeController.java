package com.ruoyi.web.controller.enterprise;

import java.nio.charset.StandardCharsets;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.Resource;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.service.EntResumeSnapshotService;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.mapper.DashboardMapper;

/**
 * 企业端投递级简历快照读取。
 *
 * <p>以 applicationId 唯一定位投递，服务端先校验当前登录企业对该投递的归属，
 * 再读取企业简历快照与企业独立 PDF；不读取 C-App 当前简历、不依赖 rbs_status。
 * 人才库（无投递上下文）仍走 TalentPoolController 的 talId 接口，不在此控制器。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/applications")
public class ApplicationResumeController extends BaseController
{
    @Autowired
    private EntResumeSnapshotService snapshotService;

    @Autowired
    private DashboardMapper dashboardMapper;

    /**
     * 投递级结构化简历快照（教育/工作/项目/技能 + 完整度）。
     * 快照不存在时由服务层抛出 SNAPSHOT_NOT_AVAILABLE，不回退当前简历。
     */
    @GetMapping("/{applicationId}/resume")
    public AjaxResult resume(@PathVariable("applicationId") Long applicationId)
    {
        return success(snapshotService.getApplicationResumeView(currentCompanyId(), applicationId));
    }

    /**
     * 投递级原始简历 PDF（内联预览，仅 Bearer 鉴权可访问）。
     * 路径为空或企业对象缺失时给出明确提示，不影响结构化简历展示。
     */
    @GetMapping("/{applicationId}/resume/pdf")
    public ResponseEntity<Resource> resumePdf(@PathVariable("applicationId") Long applicationId)
    {
        AppResumePdfDocument document =
                snapshotService.getApplicationResumePdf(currentCompanyId(), applicationId);
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(document.name() == null ? "resume.pdf" : document.name(),
                                StandardCharsets.UTF_8).build().toString())
                .header(HttpHeaders.CACHE_CONTROL, "private, no-store")
                .header("X-Content-Type-Options", "nosniff")
                .body(document.resource());
    }

    /** 解析当前登录企业；未绑定企业直接拒绝，不做默认企业兜底，避免越权读取。 */
    private Long currentCompanyId()
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(getUserId());
        if (companyId == null)
        {
            throw new ServiceException("当前账号未绑定企业");
        }
        return companyId;
    }
}
