package com.ruoyi.system.service.exam;

import java.util.List;
import java.util.Map;

/**
 * 题库数据出口：Controller 与 AI 工具层（AgentTools）只允许通过本服务读写 t_exam_question。
 *
 * 阶段 0 只下沉 AgentTools 需要的三个方法，CRUD 仍留在 admin 控制器，一行不动。
 * 注意：本阶段方法不得引用 eqs_status / eqs_hash / eqs_confidence 等未上线的列，
 * 否则 DDL 未执行时 SQL 会直接报 Unknown column。
 */
public interface IExamQuestionBankService
{
    /**
     * 公共题库检索，只返回题面信息，不返回答案。
     *
     * @param keyword    题干关键词，最长 100 字，可为空
     * @param category   分类 1-5，可为空
     * @param type       题型 1-5，可为空
     * @param difficulty 难度 1-3，可为空
     * @param count      返回条数，内部限制 1~20
     */
    List<Map<String, Object>> searchPublic(String keyword, Integer category, Integer type, Integer difficulty, int count);

    /**
     * 取单题答案/解析/选项。只允许公共题库（eqs_company_id IS NULL），企业题库不对外暴露。
     */
    Map<String, Object> getAnswer(Long questionId);

    /**
     * 批量入库。
     *
     * @param items     已通过业务校验的题目草稿
     * @param companyId 企业 ID，null 表示系统题库
     * @return {inserted, skipped, duplicated, failed, errors}
     *         skipped / duplicated 为阶段 2 查重预留，当前恒为 0
     */
    Map<String, Object> batchInsert(List<Map<String, Object>> items, Long companyId);
}
