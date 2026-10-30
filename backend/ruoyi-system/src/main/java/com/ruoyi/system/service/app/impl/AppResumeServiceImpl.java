package com.ruoyi.system.service.app.impl;

import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.mapper.app.AppResumeMapper;
import com.ruoyi.system.service.app.IAppResumeService;
import com.ruoyi.system.service.app.pdf.ResumePdfParser;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;
import com.ruoyi.system.service.app.pdf.ResumeAiStructurer;
import com.ruoyi.system.service.app.pdf.ResumeRuleStructurer;
import com.ruoyi.system.config.ResumeStructureProperties;

/** C-App 简历服务。 */
@Service
public class AppResumeServiceImpl implements IAppResumeService
{
    @Autowired
    private AppResumeMapper resumeMapper;
    @Autowired
    private ResumePdfParser pdfParser;
    @Autowired
    private ResumePdfStorage pdfStorage;
    @Autowired
    private ResumeAiStructurer aiStructurer;
    @Autowired
    private ResumeStructureProperties structureProperties;

    @Override
    public List<AppResume> selectResumeList(Long userId)
    {
        return resumeMapper.selectResumeList(userId);
    }

    @Override
    public AppResume selectResume(Long userId, Long resumeId)
    {
        AppResume resume = resumeMapper.selectResume(resumeId, userId);
        if (resume == null)
        {
            throw new ServiceException("简历不存在或无权访问");
        }
        resume.setEducations(resumeMapper.selectEducations(resumeId));
        resume.setWorks(resumeMapper.selectWorks(resumeId));
        resume.setProjects(resumeMapper.selectProjects(resumeId));
        resume.setSkills(resumeMapper.selectSkills(resumeId));
        return resume;
    }

    @Override
    @Transactional
    public AppResume saveResume(Long userId, AppResume resume)
    {
        return saveResumeInternal(userId, resume, null);
    }

    @Override
    @Transactional
    public int deleteResume(Long userId, Long resumeId)
    {
        AppResume resume = lockResume(userId, resumeId);
        if (resumeMapper.countResumeReferences(resumeId) > 0)
        {
            throw new ServiceException("该简历已关联投递记录，暂不能删除");
        }
        if (resumeMapper.softDeleteResume(resumeId, userId) <= 0)
        {
            throw new ServiceException("简历不存在或已删除");
        }
        resumeMapper.deleteEducations(resumeId);
        resumeMapper.deleteWorks(resumeId);
        resumeMapper.deleteProjects(resumeId);
        resumeMapper.deleteSkills(resumeId);
        if (Boolean.TRUE.equals(resume.getIsDefault()))
        {
            Long replacementId = resumeMapper.selectNewestActiveResumeId(userId);
            if (replacementId != null) resumeMapper.setDefaultResume(userId, replacementId);
        }
        if (StringUtils.isNotEmpty(resume.getFilePath()))
        {
            String filePath = resume.getFilePath();
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization()
            {
                @Override
                public void afterCommit()
                {
                    pdfStorage.delete(userId, filePath);
                }
            });
        }
        return 1;
    }

    @Override
    @Transactional
    public AppResume saveResumeWithPdf(Long userId, AppResume resume, byte[] pdfBytes, String originalFilename)
    {
        AppResume previous = resume.getResumeId() == null ? null : lockResume(userId, resume.getResumeId());
        normalize(resume);
        pdfParser.validate(pdfBytes);
        ResumePdfStorage.StoredPdf stored = pdfStorage.store(userId, pdfBytes, originalFilename);
        // 数据库回滚时删除新文件；提交后才删除旧文件，保留重试能力。
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization()
        {
            @Override
            public void afterCompletion(int status)
            {
                if (status != STATUS_COMMITTED) pdfStorage.delete(userId, stored.reference());
                else if (previous != null) pdfStorage.delete(userId, previous.getFilePath());
            }
        });
        return saveResumeInternal(userId, resume, stored);
    }

    @Override
    public AppResumePdfDocument selectPdf(Long userId, Long resumeId)
    {
        AppResume resume = requireResume(userId, resumeId);
        return new AppResumePdfDocument(pdfStorage.read(userId, resume.getFilePath()), resume.getFileName());
    }

    private AppResume requireResume(Long userId, Long resumeId)
    {
        AppResume resume = resumeMapper.selectResume(resumeId, userId);
        if (resume == null) throw new ServiceException("简历不存在或无权访问");
        return resume;
    }

    private AppResume saveResumeInternal(Long userId, AppResume resume, ResumePdfStorage.StoredPdf stored)
    {
        normalize(resume);
        resume.setUserId(userId);
        boolean creating = resume.getResumeId() == null;
        AppResume existing = creating ? null : lockResume(userId, resume.getResumeId());
        resume.setFilePath(stored != null ? stored.reference() : existing == null ? null : existing.getFilePath());
        resume.setFileName(stored != null ? stored.name() : existing == null ? null : existing.getFileName());
        resume.setFileSize(stored != null ? Long.valueOf(stored.size()) : existing == null ? null : existing.getFileSize());
        if (creating)
        {
            if (resumeMapper.countActiveResumes(userId) == 0)
            {
                resume.setIsDefault(true);
            }
            if (Boolean.TRUE.equals(resume.getIsDefault()))
            {
                resumeMapper.clearDefault(userId);
            }
            if (resumeMapper.insertResume(resume) <= 0)
            {
                throw new ServiceException("新建简历失败");
            }
        }
        else
        {
            if (Boolean.TRUE.equals(resume.getIsDefault()))
            {
                resumeMapper.clearDefault(userId);
            }
            if (resumeMapper.updateResume(resume) <= 0)
            {
                throw new ServiceException("保存简历失败");
            }
        }

        Long resumeId = resume.getResumeId();
        resumeMapper.deleteEducations(resumeId);
        resumeMapper.deleteWorks(resumeId);
        resumeMapper.deleteProjects(resumeId);
        resumeMapper.deleteSkills(resumeId);
        resume.getEducations().forEach(item -> resumeMapper.insertEducation(resumeId, item));
        resume.getWorks().forEach(item -> resumeMapper.insertWork(resumeId, item));
        resume.getProjects().forEach(item -> resumeMapper.insertProject(resumeId, item));
        resume.getSkills().forEach(item -> resumeMapper.insertSkill(resumeId, item));
        return selectResume(userId, resumeId);
    }

    @Override
    public AppResume parsePdf(byte[] pdfBytes, String originalFilename)
    {
        ResumePdfParser.Result parsed = pdfParser.parse(pdfBytes);
        String text = parsed.text();
        AppResume draft;
        boolean aiConfigured = aiStructurer.isConfigured();
        if (aiConfigured)
        {
            draft = aiStructurer.structure(text);
        }
        else
        {
            draft = new ResumeRuleStructurer().structure(text);
            draft.setStructureMethod("RULE");
            String warning = structureProperties.isEnabled()
                    ? "后端未配置 AI API 密钥，已使用本地 OCR/规则识别；请对照原 PDF 核对结果"
                    : "AI 编排已关闭，规则识别结果可能遗漏不同标题下的信息，请对照原文核对";
            List<String> warnings = new ArrayList<>(draft.getParseWarnings());
            warnings.add(warning);
            draft.setParseWarnings(warnings);
        }
        String baseName = originalFilename == null ? "扫描简历" : originalFilename.replaceFirst("(?i)\\.pdf$", "");
        draft.setResumeName(trimTo(baseName, 100));
        draft.setIsDefault(false);
        draft.setExtractedText(text);
        draft.setParseMethod(parsed.method());
        return draft;
    }

    private AppResume lockResume(Long userId, Long resumeId)
    {
        AppResume resume = resumeMapper.selectResumeForUpdate(resumeId, userId);
        if (resume == null) throw new ServiceException("简历不存在或无权访问");
        return resume;
    }


    private void normalize(AppResume resume)
    {
        resume.setResumeName(trimTo(resume.getResumeName(), 100));
        resume.setJobDirection(trimTo(resume.getJobDirection(), 50));
        if (StringUtils.isEmpty(resume.getResumeName())) throw new ServiceException("简历名称不能为空");
        if (resume.getIsDefault() == null) resume.setIsDefault(false);
        resume.getSkills().forEach(item -> {
            item.setName(trimTo(item.getName(), 50));
            if (item.getLevel() != null) item.setLevel(Math.max(1, Math.min(4, item.getLevel())));
        });
    }

    private String trimTo(String value, int max)
    {
        if (value == null) return null;
        String cleaned = value.trim();
        return cleaned.length() <= max ? cleaned : cleaned.substring(0, max);
    }
}
