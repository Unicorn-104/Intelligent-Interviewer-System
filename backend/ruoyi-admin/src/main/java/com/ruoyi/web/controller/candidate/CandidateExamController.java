package com.ruoyi.web.controller.candidate;

import java.util.List;
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
import com.ruoyi.common.utils.ServletUtils;
import com.ruoyi.enterprise.service.ICandidateExamService;
import com.ruoyi.enterprise.service.IExamMonitorService;

/**
 * 候选人端 - 在线笔试（我的考试、开考/续考、自动保存、交卷）
 *
 * <p>鉴权沿用 Candidate-Token 的 Bearer JWT；数据范围仅限本人投递岗位对应的
 * 考试安排，越权统一返回"考试安排不存在或无权访问"。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/candidate/exam")
public class CandidateExamController extends BaseController
{
    @Autowired
    private ICandidateExamService candidateExamService;

    @Autowired
    private IExamMonitorService examMonitorService;

    /** 我的考试列表 */
    @GetMapping("/list")
    public AjaxResult list()
    {
        return success(candidateExamService.listMyExams(getUserId()));
    }

    /** 考试入口详情（不含题目） */
    @GetMapping("/schedule/{scheduleId}")
    public AjaxResult entry(@PathVariable("scheduleId") Long scheduleId)
    {
        return success(candidateExamService.getExamEntry(getUserId(), scheduleId));
    }

    /** 设备检测准备：创建未开始记录（不计时），用于双机位测试 */
    @PostMapping("/schedule/{scheduleId}/prepare")
    public AjaxResult prepare(@PathVariable("scheduleId") Long scheduleId)
    {
        return success(candidateExamService.prepareExam(getUserId(), scheduleId));
    }

    /** 开始/续考：返回题目快照与剩余秒数 */
    @PostMapping("/schedule/{scheduleId}/start")
    public AjaxResult start(@PathVariable("scheduleId") Long scheduleId)
    {
        return success(candidateExamService.startOrResume(getUserId(), scheduleId,
                ServletUtils.getRequest().getHeader("User-Agent")));
    }

    /** 自动保存作答：body {answers:[{questionId,content}]} */
    @PostMapping("/record/{recordId}/save")
    public AjaxResult save(@PathVariable("recordId") Long recordId, @RequestBody Map<String, Object> body)
    {
        return success(candidateExamService.saveAnswers(getUserId(), recordId, answersOf(body)));
    }

    /** 交卷：body 可选 {answers:[...]} 携带最终作答 */
    @PostMapping("/record/{recordId}/submit")
    public AjaxResult submit(@PathVariable("recordId") Long recordId,
            @RequestBody(required = false) Map<String, Object> body)
    {
        return success(candidateExamService.submit(getUserId(), recordId, answersOf(body)));
    }

    /** 双机位监考信息：主机位入会令牌 + 副机位接入码与二维码地址 + 副机位状态 */
    @GetMapping("/record/{recordId}/monitor")
    public AjaxResult monitor(@PathVariable("recordId") Long recordId)
    {
        return success(examMonitorService.getMonitorInfo(getUserId(), recordId));
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> answersOf(Map<String, Object> body)
    {
        if (body == null)
        {
            return null;
        }
        Object raw = body.get("answers");
        return raw instanceof List ? (List<Map<String, Object>>) raw : null;
    }
}
