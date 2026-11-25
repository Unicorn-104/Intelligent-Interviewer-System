package com.ruoyi.web.controller.content;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.exam.IExamImportLogService;
import com.ruoyi.system.service.exam.IExamQuestionBankService;
import com.ruoyi.web.service.ExamQuestionImportParser;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 题库文件导入：解析 docx/xlsx/csv/txt/md → 切题 → 规则推断 + AI 校正分类与题型。
 * 只负责“解析预览”和“批量入库”，数据仍写 t_exam_question。
 *
 * @author TQY
 */
@RestController
@RequestMapping("/content/examQuestion/import")
public class ContentExamQuestionImportController extends BaseController
{
    @Autowired
    private ExamQuestionImportParser parser;

    /** 题库唯一数据出口，批量入库下沉到 ruoyi-system，供后续 AI 工具层复用。 */
    @Autowired
    private IExamQuestionBankService examQuestionBankService;

    /** 导入批次记录与撤销。 */
    @Autowired
    private IExamImportLogService examImportLogService;

    /** 解析上传文件（可多文件，支持一次选中整个文件夹），返回题目预览，不入库。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/parse")
    public AjaxResult parse(@RequestParam("files") MultipartFile[] files)
    {
        try
        {
            return success(parser.parse(files));
        }
        catch (ServiceException e)
        {
            return error(e.getMessage());
        }
    }

    /** AI 校正：批量识别分类/题型/难度，失败时返回空列表由前端沿用规则结果。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/classify")
    public AjaxResult classify(@RequestBody Map<String, Object> body)
    {
        List<Map<String, Object>> items = ExamQuestionImportParser.asList(body.get("items"));
        try
        {
            return success(parser.classify(items));
        }
        catch (ServiceException e)
        {
            return error(e.getMessage());
        }
    }

    /** 批量入库。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/batch")
    public AjaxResult batch(@RequestBody Map<String, Object> body)
    {
        List<Map<String, Object>> items = ExamQuestionImportParser.asList(body.get("items"));
        if (items.isEmpty())
        {
            return error("没有可导入的题目");
        }
        String bankType = ExamQuestionImportParser.str(body.get("bankType"));
        Long companyId = toLong(body.get("companyId"));
        long cid = "enterprise".equals(bankType) ? (companyId == null ? 0L : companyId) : 0L;

        List<String> errors = new ArrayList<>();
        List<Map<String, Object>> valid = new ArrayList<>();
        if ("enterprise".equals(bankType) && cid == 0L)
        {
            return error("企业题库必须指定企业");
        }
        for (Map<String, Object> item : items)
        {
            String invalid = parser.validate(item);
            if (invalid != null)
            {
                errors.add("第 " + (valid.size() + errors.size() + 1) + " 条：" + invalid);
                continue;
            }
            valid.add(item);
        }
        Map<String, Object> data = examQuestionBankService.batchInsert(valid, cid == 0L ? null : cid);
        // 校验阶段的错误与入库阶段的错误合并返回，保持前端既有字段（failed / errors）不变
        List<?> insertErrors = (List<?>) data.get("errors");
        if (insertErrors != null && !insertErrors.isEmpty())
        {
            for (Object msg : insertErrors)
            {
                errors.add(String.valueOf(msg));
            }
        }
        int failed = errors.size();
        data.put("failed", failed);
        data.put("errors", errors);

        // 记录本次导入，供「导入记录」查看与撤销
        @SuppressWarnings("unchecked")
        List<Long> savedIds = (List<Long>) data.get("ids");
        Object insertedObj = data.get("inserted");
        int inserted = insertedObj instanceof Number ? ((Number) insertedObj).intValue() : 0;
        Long batchId = examImportLogService.record(1, ExamQuestionImportParser.str(body.get("fileName")),
                cid == 0L ? null : cid, items.size(), inserted, failed, savedIds, getUsername());
        data.put("batchId", batchId);
        return success(data);
    }

    /** 导入记录分页列表。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @GetMapping("/logs")
    public AjaxResult logs(@RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "10") int pageSize)
    {
        return success(examImportLogService.list(pageNum, pageSize));
    }

    /** 撤销某一批次导入。 */
    @PreAuthorize("@ss.hasPermi('content:question:add')")
    @PostMapping("/logs/{batchId}/undo")
    public AjaxResult undo(@PathVariable Long batchId)
    {
        return success(examImportLogService.undo(batchId, getUsername()));
    }

    private static Long toLong(Object v)
    {
        if (v == null)
        {
            return null;
        }
        try
        {
            if (v instanceof Number)
            {
                return ((Number) v).longValue();
            }
            String s = String.valueOf(v).trim();
            return s.isEmpty() ? null : Long.parseLong(s);
        }
        catch (Exception e)
        {
            return null;
        }
    }
}
