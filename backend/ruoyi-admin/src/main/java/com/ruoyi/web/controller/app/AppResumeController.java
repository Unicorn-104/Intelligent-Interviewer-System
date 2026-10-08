package com.ruoyi.web.controller.app;

import java.io.IOException;
import java.util.Arrays;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.annotation.Log;
import com.ruoyi.common.core.controller.BaseController;
import com.ruoyi.common.core.domain.AjaxResult;
import com.ruoyi.common.enums.BusinessType;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.service.app.IAppResumeService;

/** C-App 结构化简历与一次性 PDF 识别接口。 */
@RestController
@RequestMapping("/app/resumes")
public class AppResumeController extends BaseController
{
    private static final long MAX_PDF_SIZE = 10L * 1024 * 1024;

    @Autowired
    private IAppResumeService resumeService;

    @GetMapping
    public AjaxResult list()
    {
        return success(resumeService.selectResumeList(getUserId()));
    }

    @GetMapping("/{resumeId}")
    public AjaxResult detail(@PathVariable Long resumeId)
    {
        return success(resumeService.selectResume(getUserId(), resumeId));
    }

    @Log(title = "C端简历", businessType = BusinessType.INSERT)
    @PostMapping
    public AjaxResult create(@Valid @RequestBody AppResume resume)
    {
        resume.setResumeId(null);
        return success(resumeService.saveResume(getUserId(), resume));
    }

    @Log(title = "C端简历", businessType = BusinessType.UPDATE)
    @PutMapping("/{resumeId}")
    public AjaxResult update(@PathVariable Long resumeId, @Valid @RequestBody AppResume resume)
    {
        resume.setResumeId(resumeId);
        return success(resumeService.saveResume(getUserId(), resume));
    }

    @Log(title = "C端简历PDF识别", businessType = BusinessType.IMPORT)
    @PostMapping(value = "/parse-pdf", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AjaxResult parsePdf(@RequestParam("file") MultipartFile file) throws IOException
    {
        validatePdf(file);
        return success(resumeService.parsePdf(file.getBytes(), file.getOriginalFilename()));
    }

    private void validatePdf(MultipartFile file) throws IOException
    {
        if (file == null || file.isEmpty()) throw new ServiceException("请选择 PDF 文件");
        if (file.getSize() > MAX_PDF_SIZE) throw new ServiceException("PDF 不能超过 10MB");
        String name = file.getOriginalFilename();
        if (name == null || !name.toLowerCase().endsWith(".pdf")) throw new ServiceException("仅支持 PDF 文件");
        String type = file.getContentType();
        if (type != null && !type.equalsIgnoreCase(MediaType.APPLICATION_PDF_VALUE)
                && !type.equalsIgnoreCase("application/octet-stream"))
        {
            throw new ServiceException("文件类型不是 PDF");
        }
        byte[] header = Arrays.copyOf(file.getBytes(), Math.min(5, (int) file.getSize()));
        if (header.length < 5 || header[0] != '%' || header[1] != 'P' || header[2] != 'D'
                || header[3] != 'F' || header[4] != '-')
        {
            throw new ServiceException("PDF 文件头校验失败");
        }
    }
}
