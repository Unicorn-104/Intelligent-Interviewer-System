package com.ruoyi.web.controller.enterprise;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.ISurveyService;

/**
 * 企业端 - 满意度调研
 *
 * <p>依据《业务功能分析》UC-17（候选人体验调研与数据分析）：
 * 面试后自动发送满意度问卷，采集候选人对流程便捷度、
 * 面试官专业度、系统易用性等方面的评分与文字反馈。</p>
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
     * UC-17：调研结果汇总（均分/评分分布/文字反馈）
     */
    @GetMapping("/results")
    public AjaxResult results(@RequestParam(required = false) Long templateId,
            @RequestParam(required = false) String from,
            @RequestParam(required = false) String to)
    {
        return success(surveyService.getResults(getUserId(), templateId, from, to));
    }

    /**
     * UC-17：问卷模板列表
     */
    @GetMapping("/templates")
    public AjaxResult templates()
    {
        return success(surveyService.listTemplates(getUserId()));
    }
}
