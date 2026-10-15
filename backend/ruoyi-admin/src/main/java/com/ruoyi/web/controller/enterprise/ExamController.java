package com.ruoyi.web.controller.enterprise;

import java.util.List;
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
import com.ruoyi.common.core.page.TableDataInfo;
import com.ruoyi.enterprise.service.IExamGradeService;
import com.ruoyi.enterprise.service.IExamMonitorService;
import com.ruoyi.enterprise.service.IExamService;

/**
 * 企业端 - 在线笔试配置（题库 CRUD、组卷、随机抽题规则、考试时长/次数、开考/截止时间、交卷规则）
 *
 * <p>数据隔离：试卷与考试安排经岗位归属校验（pos_company_id），
 * 越权统一返回"试卷不存在或无权访问"口径。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/exam")
public class ExamController extends BaseController
{
    @Autowired
    private IExamService examService;

    @Autowired
    private IExamMonitorService examMonitorService;

    @Autowired
    private IExamGradeService examGradeService;

    // ==================== 题库 ====================

    /** 题库列表（题型/难度/技能标签/关键词过滤，分页） */
    @GetMapping("/questions")
    public TableDataInfo questions(@RequestParam(required = false) Integer type,
            @RequestParam(required = false) Integer difficulty,
            @RequestParam(required = false) String skillTag,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(examService.listQuestions(type, difficulty, skillTag, keyword, pageNum, pageSize));
    }

    /** 题目详情 */
    @GetMapping("/questions/{questionId}")
    public AjaxResult question(@PathVariable("questionId") Long questionId)
    {
        return success(examService.getQuestion(questionId));
    }

    /** 新增题目 */
    @PostMapping("/questions")
    public AjaxResult createQuestion(@RequestBody Map<String, Object> body)
    {
        return success(examService.saveQuestion(body));
    }

    /** 修改题目 */
    @PutMapping("/questions/{questionId}")
    public AjaxResult updateQuestion(@PathVariable("questionId") Long questionId,
            @RequestBody Map<String, Object> body)
    {
        examService.updateQuestion(questionId, body);
        return success("保存成功");
    }

    /** 删除题目 */
    @DeleteMapping("/questions/{questionId}")
    public AjaxResult deleteQuestion(@PathVariable("questionId") Long questionId)
    {
        examService.deleteQuestion(questionId);
        return success("删除成功");
    }

    // ==================== 试卷 ====================

    /** 试卷列表（按岗位过滤） */
    @GetMapping("/papers")
    public AjaxResult papers(@RequestParam(required = false) Long positionId)
    {
        return success(examService.listPapers(getUserId(), positionId));
    }

    /** 试卷详情（含题目清单与组卷规则） */
    @GetMapping("/papers/{paperId}")
    public AjaxResult paper(@PathVariable("paperId") Long paperId)
    {
        return success(examService.getPaper(getUserId(), paperId));
    }

    /** 新建试卷（mode=manual 人工选题 / random 规则抽题） */
    @PostMapping("/papers")
    public AjaxResult createPaper(@RequestBody Map<String, Object> body)
    {
        return success(examService.createPaper(getUserId(), body));
    }

    /** 修改试卷 */
    @PutMapping("/papers/{paperId}")
    public AjaxResult updatePaper(@PathVariable("paperId") Long paperId, @RequestBody Map<String, Object> body)
    {
        examService.updatePaper(getUserId(), paperId, body);
        return success("保存成功");
    }

    /** 删除试卷 */
    @DeleteMapping("/papers/{paperId}")
    public AjaxResult deletePaper(@PathVariable("paperId") Long paperId)
    {
        examService.deletePaper(getUserId(), paperId);
        return success("删除成功");
    }

    /** 随机抽题规则预览（不落库，返回抽中题目与预计总分） */
    @PostMapping("/papers/draw-preview")
    public AjaxResult drawPreview(@RequestBody Map<String, Object> rule)
    {
        return success(examService.previewDraw(rule));
    }

    // ==================== 考试安排 ====================

    /** 考试安排列表（状态按起止时间自动流转） */
    @GetMapping("/schedules")
    public TableDataInfo schedules(@RequestParam(required = false) Long positionId,
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(examService.listSchedules(getUserId(), positionId, status, pageNum, pageSize));
    }

    /** 考试安排详情 */
    @GetMapping("/schedules/{scheduleId}")
    public AjaxResult schedule(@PathVariable("scheduleId") Long scheduleId)
    {
        return success(examService.getSchedule(getUserId(), scheduleId));
    }

    /** 新建考试安排（试卷/时长/次数/开考截止/阈值/双机位/交卷规则） */
    @PostMapping("/schedules")
    public AjaxResult createSchedule(@RequestBody Map<String, Object> body)
    {
        return success(examService.createSchedule(getUserId(), body));
    }

    /** 修改考试安排 */
    @PutMapping("/schedules/{scheduleId}")
    public AjaxResult updateSchedule(@PathVariable("scheduleId") Long scheduleId,
            @RequestBody Map<String, Object> body)
    {
        examService.updateSchedule(getUserId(), scheduleId, body);
        return success("保存成功");
    }

    /** 取消考试安排 */
    @PostMapping("/schedules/{scheduleId}/cancel")
    public AjaxResult cancelSchedule(@PathVariable("scheduleId") Long scheduleId)
    {
        examService.cancelSchedule(getUserId(), scheduleId);
        return success("已取消");
    }

    // ==================== 笔试通知 ====================

    /** 保存笔试通知配置（渠道 email/inapp、标题/正文模板、考试入口地址） */
    @PutMapping("/schedules/{scheduleId}/notify-config")
    public AjaxResult saveNotifyConfig(@PathVariable("scheduleId") Long scheduleId,
            @RequestBody Map<String, Object> body)
    {
        examService.saveNotifyConfig(getUserId(), scheduleId, body);
        return success("保存成功");
    }

    /** 通知对象列表（该安排岗位的全部投递候选人及联系方式） */
    @GetMapping("/schedules/{scheduleId}/notify-targets")
    public AjaxResult notifyTargets(@PathVariable("scheduleId") Long scheduleId)
    {
        return success(examService.listNotifyTargets(getUserId(), scheduleId));
    }

    /** 发送笔试通知（body 可选覆盖 channels/title/content/examUrl 与 candidateIds 定向） */
    @PostMapping("/schedules/{scheduleId}/notify")
    public AjaxResult sendNotify(@PathVariable("scheduleId") Long scheduleId,
            @RequestBody(required = false) Map<String, Object> body)
    {
        return success(examService.sendNotify(getUserId(), scheduleId, body));
    }

    // ==================== 双机位监考 ====================

    /** 进行中的考试记录列表（含副机位在线状态） */
    @GetMapping("/monitor/ongoing")
    public AjaxResult monitorOngoing()
    {
        return success(examMonitorService.listOngoing(getUserId()));
    }

    /** 监考观察者入会令牌（主机位+副机位两路画面并排查看） */
    @GetMapping("/monitor/record/{recordId}/token")
    public AjaxResult monitorToken(@PathVariable("recordId") Long recordId)
    {
        return success(examMonitorService.proctorToken(getUserId(), recordId));
    }

    // ==================== 成绩报告与判分 ====================

    /** 成绩报告列表（岗位/通过状态过滤，分页；含客观/主观/总分与流转评语） */
    @GetMapping("/results")
    public TableDataInfo results(@RequestParam(required = false) Long positionId,
            @RequestParam(required = false) Integer passStatus,
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "20") Integer pageSize)
    {
        return getDataTable(examGradeService.listResults(getUserId(), positionId, passStatus,
                pageNum, pageSize));
    }

    /** 成绩报告详情（记录元信息 + 逐题作答与判分明细） */
    @GetMapping("/results/{recordId}")
    public AjaxResult result(@PathVariable("recordId") Long recordId)
    {
        return success(examGradeService.getResult(getUserId(), recordId));
    }

    /** 主观题人工评分并终判（body {scores:[{questionId,score}], comment}） */
    @PutMapping("/results/{recordId}/subjective")
    @SuppressWarnings("unchecked")
    public AjaxResult gradeSubjective(@PathVariable("recordId") Long recordId,
            @RequestBody Map<String, Object> body)
    {
        Object raw = body == null ? null : body.get("scores");
        List<Map<String, Object>> scores = raw instanceof List
                ? (List<Map<String, Object>>) raw : null;
        Object comment = body == null ? null : body.get("comment");
        return success(examGradeService.gradeSubjective(getUserId(), recordId, scores,
                comment == null ? null : String.valueOf(comment)));
    }
}
