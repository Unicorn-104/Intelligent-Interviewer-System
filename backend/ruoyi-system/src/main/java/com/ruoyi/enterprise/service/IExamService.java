package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - 在线笔试配置服务（题库/组卷/考试安排）
 *
 * @author enterprise
 */
public interface IExamService
{
    /** 题库列表（平台题库 + 本企业题库，可按 scope 过滤：platform/enterprise） */
    public List<Map<String, Object>> listQuestions(Integer type, Integer difficulty,
            String skillTag, String keyword, String scope, Long userId, Integer pageNum, Integer pageSize);

    /** 题目详情 */
    public Map<String, Object> getQuestion(Long questionId);

    /** 新增题目（归属当前企业），返回 questionId */
    public Long saveQuestion(Map<String, Object> body, Long userId);

    /** 修改题目（仅限本企业题目） */
    public void updateQuestion(Long questionId, Map<String, Object> body, Long userId);

    /** 删除题目（仅限本企业题目） */
    public void deleteQuestion(Long questionId, Long userId);

    /** 补全空解析（平台题库与企业题库均可，已有解析不覆盖） */
    public void fillQuestionAnalysis(Long questionId, String analysis, Long userId);

    /** 试卷列表（按岗位过滤，企业隔离） */
    public List<Map<String, Object>> listPapers(Long userId, Long positionId);

    /** 试卷详情（含题目与组卷规则） */
    public Map<String, Object> getPaper(Long userId, Long paperId);

    /** 新建试卷（manual=选题组卷，random=规则抽卷），返回 paperId */
    public Long createPaper(Long userId, Map<String, Object> body);

    /**
     * Agent 组卷预览：AI 生成题目或从现有题库抽题，返回可编辑的题目列表（不落库、不建试卷）。
     *
     * @param body positionId/difficulty/counts/focusPoints/focusWeight/saveToBank
     * @return questions、questionCount、totalScore、saveToBank
     */
    public Map<String, Object> previewGeneratedPaper(Long userId, Map<String, Object> body);

    /**
     * Agent 规划预览：根据岗位与配额生成知识点覆盖计划，供前端编辑后再命题。
     *
     * @param body positionId/difficulty/counts/focusPoints/focusWeight
     * @return note、points（[{skillTag,weight,focus}]）
     */
    public Map<String, Object> previewPlan(Long userId, Map<String, Object> body);

    /**
     * 保存 Agent 组卷预览结果：按编辑后的题目生成试卷；saveToBank=true 时题目同时写入企业题库。
     *
     * @param body positionId/name/durationMin/saveToBank/questions
     * @return paperId、name、questionCount、totalScore
     */
    public Map<String, Object> saveGeneratedPaper(Long userId, Map<String, Object> body);

    /** 修改试卷（名称/时长/规则/题目） */
    public void updatePaper(Long userId, Long paperId, Map<String, Object> body);

    /** 启用/禁用试卷（禁用后不可用于新的考试安排） */
    public void updatePaperStatus(Long userId, Long paperId, Integer status);

    /** 删除试卷（存在进行中安排时禁止） */
    public void deletePaper(Long userId, Long paperId);

    /** 随机抽题规则预览（返回抽中题目与预计总分） */
    public Map<String, Object> previewDraw(Map<String, Object> rule, Long userId);

    /** 考试安排列表（时长/次数/起止时间/交卷规则） */
    public List<Map<String, Object>> listSchedules(Long userId, Long positionId, Integer status,
            Integer pageNum, Integer pageSize);

    /** 考试安排详情 */
    public Map<String, Object> getSchedule(Long userId, Long scheduleId);

    /** 新建考试安排，返回 scheduleId */
    public Long createSchedule(Long userId, Map<String, Object> body);

    /** 修改考试安排（已结束/已取消不可改） */
    public void updateSchedule(Long userId, Long scheduleId, Map<String, Object> body);

    /** 取消考试安排 */
    public void cancelSchedule(Long userId, Long scheduleId);

    /** 保存笔试通知配置（渠道/标题/正文模板/考试入口地址） */
    public void saveNotifyConfig(Long userId, Long scheduleId, Map<String, Object> body);

    /** 通知对象列表（该安排岗位的全部投递候选人及联系方式） */
    public List<Map<String, Object>> listNotifyTargets(Long userId, Long scheduleId);

    /** 发送笔试通知（email/inapp 渠道），返回逐人发送结果 */
    public Map<String, Object> sendNotify(Long userId, Long scheduleId, Map<String, Object> body);
}
