package com.ruoyi.web.controller.enterprise;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.ITalentPoolService;

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
     * UC-03：人才库检索（关键词/标签 + 分页）
     */
    @GetMapping("/list")
    public TableDataInfo list(@RequestParam(required = false) String keyword,
            @RequestParam(required = false) String tag,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(talentPoolService.listTalents(getUserId(), keyword, tag, pageNum, pageSize));
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
}
