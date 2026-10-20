package com.ruoyi.web.controller.enterprise;

import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.enterprise.service.ISurveyService;

/**
 * 企业端 - 满意度调研
 *
 * <p>依据《业务功能分析》UC-17（候选人体验调研与数据分析）：
 * HR 在消息中心选择问卷模板发送给候选人，系统生成匿名填写链接与发送记录，
 * 并汇总回收结果（均分、评分分布、文字反馈）供 HR 分析。
 * 问卷模板可见范围为平台通用模板 + 本企业自有模板，数据按企业隔离。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/survey")
public class SurveyController extends BaseController
{
    @Autowired
    private ISurveyService surveyService;

    /**
     * UC-17：调研结果汇总（均分/评分分布/发送与回收统计/回收明细）
     */
    @GetMapping("/results")
    public AjaxResult results(@RequestParam(required = false) Long templateId,
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to)
    {
        return success(surveyService.getResults(getUserId(), templateId, from, to));
    }

    /**
     * UC-17：问卷模板列表；all=true 返回含停用模板的完整列表（用于配置页）
     */
    @GetMapping("/templates")
    public AjaxResult templates(@RequestParam(required = false) Boolean all)
    {
        return success(surveyService.listTemplates(getUserId(), all));
    }

    /**
     * UC-17：新增本企业问卷模板
     */
    @PostMapping("/templates")
    public AjaxResult createTemplate(@RequestBody Map<String, Object> body)
    {
        return success(surveyService.createTemplate(getUserId(), body));
    }

    /**
     * UC-17：修改本企业问卷模板（含触发场景与启停用）
     */
    @PutMapping("/templates/{templateId}")
    public AjaxResult updateTemplate(@PathVariable("templateId") Long templateId,
            @RequestBody Map<String, Object> body)
    {
        return success(surveyService.updateTemplate(getUserId(), templateId, body));
    }

    /**
     * UC-17：启停用本企业问卷模板
     */
    @PutMapping("/templates/{templateId}/status")
    public AjaxResult updateTemplateStatus(@PathVariable("templateId") Long templateId,
            @RequestBody Map<String, Object> body)
    {
        surveyService.updateTemplateStatus(getUserId(), templateId,
                body.get("status") == null ? null : Integer.valueOf(String.valueOf(body.get("status"))));
        return success();
    }

    /**
     * UC-17：删除本企业问卷模板
     */
    @DeleteMapping("/templates/{templateId}")
    public AjaxResult deleteTemplate(@PathVariable("templateId") Long templateId)
    {
        surveyService.deleteTemplate(getUserId(), templateId);
        return success();
    }

    /**
     * UC-17：向候选人发送调研问卷，返回匿名链接令牌与发送信息
     */
    @PostMapping("/send")
    public AjaxResult send(@RequestBody Map<String, Object> body)
    {
        Long candidateUserId = body.get("candidateUserId") == null ? null
                : Long.valueOf(String.valueOf(body.get("candidateUserId")));
        Long templateId = body.get("templateId") == null ? null
                : Long.valueOf(String.valueOf(body.get("templateId")));
        return success(surveyService.send(getUserId(), candidateUserId, templateId));
    }
}
