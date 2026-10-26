package com.ruoyi.web.controller.enterprise;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.IEnterpriseJdService;

/**
 * 企业端 - 岗位画像（JD Profile）
 *
 * <p>依据《业务功能分析》UC-01（发布岗位并生成 JD 画像）：
 * HR 发布岗位后，系统解析 JD 文本，提取学历、年限、技能标签等
 * 硬性指标与软性要求，生成结构化"岗位画像"，作为后续 AI 筛选的标尺。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/jd")
public class EnterpriseJdController extends BaseController
{
    @Autowired
    private IEnterpriseJdService jdService;

    /**
     * UC-01：解析 JD 文本生成岗位画像
     */
    @PostMapping("/parse")
    public AjaxResult parse(@RequestBody Map<String, Object> body)
    {
        Long positionId = asLong(body.get("positionId"));
        String jdText = body.get("jdText") == null ? null : String.valueOf(body.get("jdText"));
        return success(jdService.parseJd(positionId, jdText));
    }

    /**
     * 仅解析 JD 文本（不写库，供发布/编辑岗位表单回填）
     */
    @PostMapping("/analyze")
    public AjaxResult analyze(@RequestBody Map<String, Object> body)
    {
        String jdText = body.get("jdText") == null ? null : String.valueOf(body.get("jdText"));
        return success(jdService.analyzeJd(jdText));
    }

    /**
     * UC-01：查看岗位画像（硬性指标/软性要求/技能标签）
     */
    @GetMapping("/{posId}")
    public AjaxResult get(@PathVariable("posId") Long posId)
    {
        return success(jdService.getJdProfile(posId));
    }

    private Long asLong(Object v)
    {
        if (v == null)
        {
            return null;
        }
        if (v instanceof Number)
        {
            return ((Number) v).longValue();
        }
        String s = v.toString().trim();
        return s.isEmpty() ? null : Long.valueOf(s);
    }
}
