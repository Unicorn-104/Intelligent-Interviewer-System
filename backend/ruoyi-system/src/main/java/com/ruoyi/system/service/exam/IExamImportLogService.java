package com.ruoyi.system.service.exam;

import java.util.List;
import java.util.Map;

/**
 * 题库导入批次记录：记录每次文件导入/单条新增，并支持按批次撤销。
 *
 * 依赖表 t_exam_question_import_batch（见 backend/sql/2026-11-exam-ai/03_*.sql）。
 * 撤销只删除仍存在且未被考卷引用的题目，已引用或被手工删除的不动。
 */
public interface IExamImportLogService
{
    /**
     * 写入一条批次记录。
     *
     * @param type        1 文件导入，2 单条新增
     * @param fileName    文件名，单条新增传 null
     * @param companyId   企业 ID，null 表示系统题库
     * @param total       提交条数
     * @param inserted    成功条数
     * @param failed      失败条数
     * @param questionIds 本批真正写入的题目 ID，可为空
     * @param operator    操作人
     * @return 批次 ID
     */
    Long record(Integer type, String fileName, Long companyId, int total, int inserted, int failed,
            List<Long> questionIds, String operator);

    /** 导入记录分页列表，按时间倒序。 */
    Map<String, Object> list(int pageNum, int pageSize);

    /** 导入记录分页列表（仅指定企业），按时间倒序。 */
    Map<String, Object> listByCompany(Long companyId, int pageNum, int pageSize);

    /**
     * 撤销一次导入。
     *
     * @return {deleted, skipped, referenced, batchId, status}
     *         skipped = 已不存在或已被考卷引用而未删除的条数
     */
    Map<String, Object> undo(Long batchId, String operator);

    /**
     * 撤销一次导入（企业端）：仅允许撤销本企业批次，且只删除本企业题目。
     *
     * @return 同 {@link #undo(Long, String)}
     */
    Map<String, Object> undoByCompany(Long batchId, Long companyId, String operator);
}
