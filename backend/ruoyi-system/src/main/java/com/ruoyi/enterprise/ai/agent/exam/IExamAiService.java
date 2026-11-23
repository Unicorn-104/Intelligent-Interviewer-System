package com.ruoyi.enterprise.ai.agent.exam;

import java.util.List;
import java.util.Map;

/**
 * 题库 AI 辅助：补全答案解析并校验题目本身是否正确；按岗位与配额智能命题组卷。
 *
 * @author enterprise
 */
public interface IExamAiService
{
    /**
     * 根据题干、选项与标准答案生成答案解析，并返回题目校验结果。
     *
     * @param body 题目信息（type、typeName、content、options、answer、difficulty、skillTag）
     * @return analysis（解析文本）、valid（题目是否通过校验）、issues（校验发现的问题）
     */
    Map<String, Object> analyzeQuestion(Map<String, Object> body);

    /**
     * Agent 规划阶段：根据岗位与配额制定知识点覆盖计划（只读，不落库）。
     *
     * @param request positionTitle/description/skills/education/experience/difficulty/counts/focusPoints/focusWeight
     * @return note（命题策略）、points（[{skillTag,weight,focus}]）；失败时返回空规划
     */
    Map<String, Object> planPaper(Map<String, Object> request);

    /**
     * Agent 命题阶段：按知识点规划生成指定题型的题目（只生成，不落库）。
     *
     * @param request 岗位与配额信息（同 planPaper）
     * @param type 题型 1~5
     * @param count 需要生成的题量
     * @param plan 规划阶段返回的知识点计划
     * @param avoidStems 需要避免重复的既有题干
     * @return 规范化题目列表
     */
    List<Map<String, Object>> generateQuestionsByType(Map<String, Object> request, int type, int count,
            Map<String, Object> plan, List<String> avoidStems);

    /**
     * Agent 自检阶段：审校题目，返回不合格题目的下标；调用失败时返回空列表（降级不阻塞）。
     *
     * @param questions 待审校题目
     * @return 不合格题目下标
     */
    List<Integer> reviewQuestions(List<Map<String, Object>> questions, Map<String, Object> plan);
}
