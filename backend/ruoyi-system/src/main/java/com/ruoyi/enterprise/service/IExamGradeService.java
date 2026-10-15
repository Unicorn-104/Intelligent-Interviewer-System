package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 企业端 - 笔试判分与成绩报告服务层
 *
 * <p>交卷后自动判分（单选/多选/判断按标准答案比对回填对错与得分）；
 * 含主观题的试卷先置"待主观题评分"，人工录入主观分后终判。
 * 通过：人才库状态"笔试通过"并按考试安排配置自动创建面试邀约
 * （复用 IInterviewScheduleService.invite）；未通过：状态"笔试未通过"归档人才库。</p>
 *
 * @author enterprise
 */
public interface IExamGradeService
{
    /** 交卷触发判分：客观题自动判分 + 报告生成 + 通过/未通过流转 */
    public Map<String, Object> gradeOnSubmit(Long recordId);

    /** 人工录入主观题得分并终判（企业侧，含归属校验与流转） */
    public Map<String, Object> gradeSubjective(Long userId, Long recordId,
            List<Map<String, Object>> scores, String comment);

    /** 成绩报告列表（企业隔离，岗位/通过状态过滤，分页） */
    public List<Map<String, Object>> listResults(Long userId, Long positionId,
            Integer passStatus, Integer pageNum, Integer pageSize);

    /** 成绩报告详情（记录元信息 + 逐题作答与判分明细） */
    public Map<String, Object> getResult(Long userId, Long recordId);
}
