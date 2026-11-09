package com.ruoyi.enterprise.service;

import java.util.Map;

/**
 * 题库 AI 辅助：补全答案解析并校验题目本身是否正确。
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
}
