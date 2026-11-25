package com.ruoyi.web.controller.enterprise;

import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.IEnterpriseSettingsService;
import com.ruoyi.system.service.exam.IExamImportLogService;
import com.ruoyi.system.service.exam.IExamQuestionBankService;
import com.ruoyi.web.service.ExamQuestionImportParser;
import org.springframework.beans.factory.annotation.Autowired;
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
 * 企业端 - 题库文件导入：解析预览、AI 校正、批量入库、导入记录与撤销。
 *
 * <p>与平台管理端的区别：不信任前端传入的企业归属，统一由当前登录用户解析，
 * 入库、导入记录、撤销均限定在当前企业题库内。</p>
 *
 * @author enterprise
 */
@RestController
@RequestMapping("/enterprise/exam/questions/import")
public class EnterpriseExamQuestionImportController extends BaseController
{
    @Autowired
    private ExamQuestionImportParser parser;

    @Autowired
    private IExamQuestionBankService examQuestionBankService;

    @Autowired
    private IExamImportLogService examImportLogService;

    @Autowired
    private IEnterpriseSettingsService settingsService;

    /** 解析上传文件（可多文件），返回题目预览，不入库。 */
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

    /** AI 校正分类/题型/难度，失败时由前端沿用规则识别结果。 */
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

    /** 批量入库到当前企业题库。 */
    @PostMapping("/batch")
    public AjaxResult batch(@RequestBody Map<String, Object> body)
    {
        List<Map<String, Object>> items = ExamQuestionImportParser.asList(body.get("items"));
        if (items.isEmpty())
        {
            return error("没有可导入的题目");
        }
        Long companyId = settingsService.requireCompanyId(getUserId());

        List<String> errors = new ArrayList<>();
        List<Map<String, Object>> valid = new ArrayList<>();
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
        Map<String, Object> data = examQuestionBankService.batchInsert(valid, companyId);
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

        @SuppressWarnings("unchecked")
        List<Long> savedIds = (List<Long>) data.get("ids");
        Object insertedObj = data.get("inserted");
        int inserted = insertedObj instanceof Number ? ((Number) insertedObj).intValue() : 0;
        Long batchId = examImportLogService.record(1, ExamQuestionImportParser.str(body.get("fileName")),
                companyId, items.size(), inserted, failed, savedIds, getUsername());
        data.put("batchId", batchId);
        return success(data);
    }

    /** 本企业导入记录分页列表。 */
    @GetMapping("/logs")
    public AjaxResult logs(@RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "10") int pageSize)
    {
        return success(examImportLogService.listByCompany(settingsService.requireCompanyId(getUserId()),
                pageNum, pageSize));
    }

    /** 撤销本企业某一批次导入。 */
    @PostMapping("/logs/{batchId}/undo")
    public AjaxResult undo(@PathVariable Long batchId)
    {
        return success(examImportLogService.undoByCompany(batchId,
                settingsService.requireCompanyId(getUserId()), getUsername()));
    }
}
