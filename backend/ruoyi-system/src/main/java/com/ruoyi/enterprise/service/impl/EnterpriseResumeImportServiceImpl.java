package com.ruoyi.enterprise.service.impl;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.EnterpriseResumeImportMapper;
import com.ruoyi.enterprise.service.IEnterpriseResumeImportService;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.service.app.IAppResumeService;

/**
 * 企业端简历批量导入实现
 */
@Service
public class EnterpriseResumeImportServiceImpl implements IEnterpriseResumeImportService
{
    private static final Pattern PHONE = Pattern.compile("1[3-9]\\d{9}");
    private static final Pattern EMAIL = Pattern.compile("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");

    @Autowired
    private EnterpriseResumeImportMapper importMapper;

    @Autowired
    private IAppResumeService resumeService;

    @Override
    public List<Map<String, Object>> batchImport(Long userId, List<MultipartFile> files, boolean deduplicate)
    {
        if (files == null || files.isEmpty())
        {
            throw new ServiceException("请选择需要导入的简历文件");
        }
        Long companyId = importMapper.selectCompanyIdByUser(userId);
        if (companyId == null)
        {
            throw new ServiceException("当前账号未绑定企业，无法导入简历");
        }
        List<Map<String, Object>> results = new ArrayList<>();
        for (MultipartFile file : files)
        {
            results.add(importOne(companyId, file, deduplicate));
        }
        return results;
    }

    private Map<String, Object> importOne(Long companyId, MultipartFile file, boolean deduplicate)
    {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("fileName", file == null ? "" : String.valueOf(file.getOriginalFilename()));
        try
        {
            if (file == null || file.isEmpty())
            {
                return fail(row, "文件为空");
            }
            String original = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
            if (!original.toLowerCase().endsWith(".pdf"))
            {
                return fail(row, "仅支持 PDF 文件");
            }
            AppResume parsed = resumeService.parsePdf(file.getBytes(), original);
            String text = parsed.getExtractedText() == null ? "" : parsed.getExtractedText();
            String phone = firstMatch(PHONE, text);
            String email = firstMatch(EMAIL, text);
            Long candidateUserId = phone == null ? null : importMapper.selectUserIdByPhone(phone);
            if (candidateUserId == null && email != null)
            {
                candidateUserId = importMapper.selectUserIdByEmail(email);
            }
            if (candidateUserId == null)
            {
                return fail(row, "未匹配到已注册候选人账号（手机号/邮箱均未命中，可请候选人先注册后重试）");
            }
            row.put("candidateName", importMapper.selectNickName(candidateUserId));
            Map<String, Object> candidate = importMapper.selectCandidate(candidateUserId, companyId);
            if (deduplicate && candidate != null)
            {
                row.put("status", "duplicate");
                row.put("talId", candidate.get("talId"));
                row.put("message", "候选人已在企业人才库，已跳过");
                return row;
            }
            if (deduplicate && importMapper.selectResumeIdByName(candidateUserId, parsed.getResumeName()) != null)
            {
                row.put("status", "duplicate");
                row.put("talId", candidate == null ? null : candidate.get("talId"));
                row.put("message", "同名简历已存在，已跳过");
                return row;
            }
            parsed.setResumeId(null);
            parsed.setIsDefault(false);
            AppResume saved = resumeService.saveResume(candidateUserId, parsed);
            if (candidate == null)
            {
                importMapper.insertCandidate(candidateUserId, companyId);
                candidate = importMapper.selectCandidate(candidateUserId, companyId);
            }
            Long talId = candidate == null || candidate.get("talId") == null ? null : Long.valueOf(String.valueOf(candidate.get("talId")));
            if (talId != null)
            {
                importMapper.updateCandidateResume(talId, saved.getResumeId());
            }
            row.put("status", "success");
            row.put("talId", talId);
            row.put("resumeId", saved.getResumeId());
            row.put("message", "导入成功");
            return row;
        }
        catch (ServiceException e)
        {
            return fail(row, e.getMessage());
        }
        catch (Exception e)
        {
            return fail(row, "解析失败：" + e.getMessage());
        }
    }

    private Map<String, Object> fail(Map<String, Object> row, String message)
    {
        row.put("status", "failed");
        row.put("message", message);
        return row;
    }

    private String firstMatch(Pattern pattern, String text)
    {
        Matcher matcher = pattern.matcher(text);
        return matcher.find() ? matcher.group() : null;
    }
}
