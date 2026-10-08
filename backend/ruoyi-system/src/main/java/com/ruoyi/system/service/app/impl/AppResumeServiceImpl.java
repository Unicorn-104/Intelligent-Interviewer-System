package com.ruoyi.system.service.app.impl;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import net.sourceforge.tess4j.ITesseract;
import net.sourceforge.tess4j.Tesseract;
import net.sourceforge.tess4j.TesseractException;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.mapper.app.AppResumeMapper;
import com.ruoyi.system.service.app.IAppResumeService;

/** C-App 简历服务。 */
@Service
public class AppResumeServiceImpl implements IAppResumeService
{
    private static final int MAX_PAGES = 8;
    private static final Pattern DATE_RANGE = Pattern.compile("((?:19|20)\\d{2})[./年-]?(\\d{1,2})?.{0,4}(?:至|[-–—~]|到).{0,4}((?:19|20)\\d{2})?[./年-]?(\\d{1,2})?");
    private static final Pattern JOB_DIRECTION = Pattern.compile("(?:求职意向|目标职位|应聘职位|期望职位)\\s*[:：]?\\s*([^\\n]{2,40})");

    @Autowired
    private AppResumeMapper resumeMapper;

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
        normalize(resume);
        resume.setUserId(userId);
        boolean creating = resume.getResumeId() == null;
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
            if (resumeMapper.selectResume(resume.getResumeId(), userId) == null)
            {
                throw new ServiceException("简历不存在或无权访问");
            }
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
        String text = extractPdfText(pdfBytes);
        if (text.replaceAll("\\s", "").length() < 20)
        {
            throw new ServiceException("未识别到有效简历内容，请上传清晰、方向正确的扫描件");
        }
        AppResume draft = parseStructured(text);
        String baseName = originalFilename == null ? "扫描简历" : originalFilename.replaceFirst("(?i)\\.pdf$", "");
        draft.setResumeName(trimTo(baseName, 100));
        draft.setIsDefault(false);
        return draft;
    }

    private String extractPdfText(byte[] bytes)
    {
        try (PDDocument document = Loader.loadPDF(bytes))
        {
            if (document.getNumberOfPages() == 0 || document.getNumberOfPages() > MAX_PAGES)
            {
                throw new ServiceException("PDF 页数需为 1-" + MAX_PAGES + " 页");
            }
            String embedded = new PDFTextStripper().getText(document);
            if (embedded.replaceAll("\\s", "").length() >= 80)
            {
                return embedded;
            }
            return recognizePages(document);
        }
        catch (ServiceException error)
        {
            throw error;
        }
        catch (IOException error)
        {
            throw new ServiceException("PDF 文件损坏或无法读取");
        }
    }

    private String recognizePages(PDDocument document)
    {
        Path dataDir = null;
        try
        {
            dataDir = Files.createTempDirectory("resume-ocr-");
            copyModel("chi_sim.traineddata", dataDir);
            copyModel("eng.traineddata", dataDir);
            ITesseract ocr = new Tesseract();
            ocr.setDatapath(dataDir.toString());
            ocr.setLanguage("chi_sim+eng");
            ocr.setPageSegMode(6);
            ocr.setVariable("user_defined_dpi", "220");
            PDFRenderer renderer = new PDFRenderer(document);
            StringBuilder text = new StringBuilder();
            for (int page = 0; page < document.getNumberOfPages(); page++)
            {
                BufferedImage image = renderer.renderImageWithDPI(page, 220, ImageType.GRAY);
                text.append(ocr.doOCR(image)).append('\n');
                image.flush();
            }
            return text.toString();
        }
        catch (IOException | TesseractException error)
        {
            throw new ServiceException("扫描件识别失败，请确认 PDF 清晰后重试");
        }
        finally
        {
            if (dataDir != null)
            {
                try
                {
                    Files.walk(dataDir).sorted((a, b) -> b.compareTo(a)).forEach(path -> {
                        try { Files.deleteIfExists(path); } catch (IOException ignored) { }
                    });
                }
                catch (IOException ignored) { }
            }
        }
    }

    private void copyModel(String name, Path target) throws IOException
    {
        ClassPathResource resource = new ClassPathResource("tessdata/" + name);
        try (InputStream input = resource.getInputStream())
        {
            Files.copy(input, target.resolve(name), StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private AppResume parseStructured(String raw)
    {
        String text = raw.replace('\r', '\n').replaceAll("[ \\t]+", " ").replaceAll("\\n{2,}", "\\n").trim();
        List<String> lines = Arrays.stream(text.split("\\n"))
                .map(String::trim).filter(line -> !line.isEmpty()).collect(Collectors.toList());
        AppResume result = new AppResume();
        Matcher direction = JOB_DIRECTION.matcher(text);
        if (direction.find()) result.setJobDirection(trimTo(direction.group(1), 50));

        parseEducations(lines, result);
        parseWorks(lines, result);
        parseProjects(lines, result);
        parseSkills(lines, result);
        return result;
    }

    private void parseEducations(List<String> lines, AppResume result)
    {
        for (String line : lines)
        {
            if (!(line.contains("大学") || line.contains("学院") || line.contains("学校"))) continue;
            AppResume.Education item = new AppResume.Education();
            String[] parts = line.split("[|｜·•\\s]{2,}");
            item.setSchool(trimTo(parts[0], 100));
            item.setDegree(degreeOf(line));
            if (parts.length > 1) item.setMajor(trimTo(parts[1].replaceAll("本科|硕士|博士|大专|专科", "").trim(), 50));
            applyDates(line, item);
            result.getEducations().add(item);
            if (result.getEducations().size() >= 5) break;
        }
    }

    private void parseWorks(List<String> lines, AppResume result)
    {
        for (int index = 0; index < lines.size(); index++)
        {
            String line = lines.get(index);
            if (!(line.contains("公司") || line.contains("集团") || line.contains("科技"))) continue;
            if (line.length() > 100) continue;
            AppResume.Work item = new AppResume.Work();
            String[] parts = line.split("[|｜·•\\s]{2,}");
            item.setCompany(trimTo(parts[0], 100));
            item.setPosition(parts.length > 1 ? trimTo(parts[1], 50) : "待确认职位");
            item.setDescription(index + 1 < lines.size() ? trimTo(lines.get(index + 1), 1000) : null);
            item.setCurrent(line.contains("至今"));
            applyDates(line, item);
            result.getWorks().add(item);
            if (result.getWorks().size() >= 8) break;
        }
    }

    private void parseProjects(List<String> lines, AppResume result)
    {
        int start = sectionIndex(lines, "项目经历", "项目经验");
        int end = nextSection(lines, start, "技能", "教育", "工作", "自我评价");
        if (start < 0) return;
        for (int i = start + 1; i < end && result.getProjects().size() < 6; i++)
        {
            String line = lines.get(i);
            if (line.length() < 3 || line.length() > 80) continue;
            AppResume.Project item = new AppResume.Project();
            item.setName(trimTo(line, 100));
            if (i + 1 < end) item.setDescription(trimTo(lines.get(++i), 1000));
            result.getProjects().add(item);
        }
    }

    private void parseSkills(List<String> lines, AppResume result)
    {
        int start = sectionIndex(lines, "专业技能", "技能标签", "技能特长", "技能");
        int end = nextSection(lines, start, "教育", "工作", "项目", "自我评价", "证书");
        if (start < 0) return;
        Set<String> names = new LinkedHashSet<>();
        for (int i = start + 1; i < end; i++)
        {
            for (String token : lines.get(i).split("[,，、/|｜;；·•\\s]+"))
            {
                String name = token.replaceAll("^[0-9.、-]+", "").trim();
                if (name.length() >= 2 && name.length() <= 30) names.add(name);
            }
        }
        names.stream().limit(15).forEach(name -> {
            AppResume.Skill skill = new AppResume.Skill();
            skill.setName(name);
            skill.setLevel(2);
            result.getSkills().add(skill);
        });
    }

    private int sectionIndex(List<String> lines, String... labels)
    {
        for (int i = 0; i < lines.size(); i++)
        {
            String compact = lines.get(i).replaceAll("\\s", "");
            for (String label : labels) if (compact.equals(label) || compact.startsWith(label + "：")) return i;
        }
        return -1;
    }

    private int nextSection(List<String> lines, int start, String... labels)
    {
        if (start < 0) return lines.size();
        for (int i = start + 1; i < lines.size(); i++)
        {
            String compact = lines.get(i).replaceAll("\\s", "");
            for (String label : labels) if (compact.equals(label) || compact.startsWith(label + "：")) return i;
        }
        return lines.size();
    }

    private int degreeOf(String line)
    {
        if (line.contains("博士")) return 5;
        if (line.contains("硕士")) return 4;
        if (line.contains("本科") || line.contains("学士")) return 3;
        if (line.contains("大专") || line.contains("专科")) return 2;
        return 3;
    }

    private void applyDates(String line, Object target)
    {
        Matcher matcher = DATE_RANGE.matcher(line);
        if (!matcher.find()) return;
        LocalDate start = dateOf(matcher.group(1), matcher.group(2));
        LocalDate end = dateOf(matcher.group(3), matcher.group(4));
        if (target instanceof AppResume.Education item) { item.setStartDate(start); item.setEndDate(end); }
        if (target instanceof AppResume.Work item) { item.setStartDate(start); item.setEndDate(end); }
    }

    private LocalDate dateOf(String year, String month)
    {
        if (year == null) return null;
        int safeMonth = month == null ? 1 : Math.max(1, Math.min(12, Integer.parseInt(month)));
        return LocalDate.of(Integer.parseInt(year), safeMonth, 1);
    }

    private void normalize(AppResume resume)
    {
        resume.setResumeName(trimTo(resume.getResumeName(), 100));
        resume.setJobDirection(trimTo(resume.getJobDirection(), 50));
        if (StringUtils.isEmpty(resume.getResumeName())) throw new ServiceException("简历名称不能为空");
        if (resume.getIsDefault() == null) resume.setIsDefault(false);
        resume.getSkills().forEach(item -> {
            item.setName(trimTo(item.getName(), 50));
            int level = item.getLevel() == null ? 2 : item.getLevel();
            item.setLevel(Math.max(1, Math.min(4, level)));
        });
    }

    private String trimTo(String value, int max)
    {
        if (value == null) return null;
        String cleaned = value.trim();
        return cleaned.length() <= max ? cleaned : cleaned.substring(0, max);
    }
}
