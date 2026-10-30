package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;

/**
 * 候选人端 - 在线笔试服务（我的考试、开考/续考、自动保存、交卷）
 *
 * @author enterprise
 */
public interface ICandidateExamService
{
    /** 我的考试列表（投递岗位对应的考试安排 + 本人记录状态） */
    public List<Map<String, Object>> listMyExams(Long userId);

    /** 考试入口详情（安排+试卷信息+本人记录状态，不含题目） */
    public Map<String, Object> getExamEntry(Long userId, Long scheduleId);

    /** 设备检测准备：建/取未开始的考试记录，供双机位测试使用，不消耗答题时长 */
    public Map<String, Object> prepareExam(Long userId, Long scheduleId);

    /** 开始/续考：首次开考抽题快照，返回题目（不含标准答案）与剩余秒数 */
    public Map<String, Object> startOrResume(Long userId, Long scheduleId, String deviceInfo);

    /** 自动保存作答（仅快照内题目） */
    public Map<String, Object> saveAnswers(Long userId, Long recordId, List<Map<String, Object>> answers);

    /** 交卷（可携带最终作答；超时按 submitRule.autoSubmit 处理） */
    public Map<String, Object> submit(Long userId, Long recordId, List<Map<String, Object>> answers);
}
