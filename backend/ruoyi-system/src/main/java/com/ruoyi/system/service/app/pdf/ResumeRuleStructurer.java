package com.ruoyi.system.service.app.pdf;

import java.time.DateTimeException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import com.ruoyi.system.domain.app.AppResume;

public class ResumeRuleStructurer
{
    private static final String DATE = "(?:19|20)\\d{2}(?:[./年-]\\d{1,2}(?:[./月-]\\d{1,2}日?)?月?)?";
    private static final Pattern RANGE = Pattern.compile("(" + DATE + ")\\s*(?:至|到|[-–—~～])\\s*(" + DATE + "|至今|现在|今)");
    private static final Pattern SCHOOL = Pattern.compile("^(?:学校(?:名称)?\\s*[:：]\\s*)?([^|｜,，;；\\s:：]{2,}?(?:大学|学院|学校|中学))(?=$|[|｜,，;；\\s])");
    private static final Pattern COMPANY = Pattern.compile("^(?:公司(?:名称)?\\s*[:：]\\s*)?([^|｜,，;；\\s:：]{2,}?(?:公司|集团|事务所|研究院))(?=$|[|｜,，;；\\s])");
    private static final Pattern DEGREE = Pattern.compile("博士|硕士|本科|学士|大专|专科|中专");
    private static final Pattern HEADING = Pattern.compile("^(教育背景|教育经历|学习经历|工作经历|工作经验|实习经历|实习经验|项目经历|项目经验|专业技能|技能标签|技能特长|技能|自我评价|自我介绍|个人总结|荣誉奖项|获奖经历|证书|资格证书|校园经历|个人信息|基本信息|联系方式|求职意向|目标职位|应聘职位|期望职位)\\s*(?:[:：]\\s*(.*))?$");

    public AppResume structure(String raw)
    {
        AppResume resume = new AppResume();
        Set<String> warnings = new LinkedHashSet<>();
        List<String> unclassified = new ArrayList<>();
        String section = "";
        String pendingDates = "";
        boolean datesBeforeRecord = false;
        AppResume.Education education = null;
        AppResume.Work work = null;
        AppResume.Project project = null;
        for (String original : raw.replace('\r', '\n').split("\\n"))
        {
            String line = original.trim().replaceFirst("^[•●▪]\\s*", "");
            if (line.isEmpty()) continue;
            Matcher heading = HEADING.matcher(line.replaceAll("(?<=\\p{IsHan})[ \\t]+(?=\\p{IsHan})", ""));
            if (heading.matches())
            {
                preservePendingDates(pendingDates, unclassified, warnings);
                String label = heading.group(1);
                section = label.matches("教育背景|教育经历|学习经历") ? "education"
                        : label.matches("工作经历|工作经验|实习经历|实习经验") ? "work"
                        : label.matches("项目经历|项目经验") ? "project"
                        : label.matches("专业技能|技能标签|技能特长|技能") ? "skill"
                        : label.matches("求职意向|目标职位|应聘职位|期望职位") ? "direction" : "other";
                education = null;
                work = null;
                project = null;
                pendingDates = "";
                datesBeforeRecord = false;
                if (line.indexOf('：') < 0 && line.indexOf(':') < 0) continue;
                line = value(line);
                if (line.isEmpty()) continue;
            }
            if (section.equals("direction"))
            {
                if (resume.getJobDirection() == null)
                {
                    resume.setJobDirection(limit(line.split("[|｜;；]", 2)[0], 50));
                    section = "other";
                    continue;
                }
            }
            String dateLine = normalizeDateLine(line);
            Matcher range = RANGE.matcher(dateLine);
            String withoutDates = range.replaceAll("").replaceFirst("^[\\s|｜,，;；]+", "").trim();
            if (withoutDates.isEmpty() && range.reset().find())
            {
                Object current = education != null ? education : work != null ? work : project;
                if (!datesBeforeRecord && hasNoDates(current))
                {
                    applyDates(dateLine, current, warnings);
                }
                else
                {
                    preservePendingDates(pendingDates, unclassified, warnings);
                    pendingDates = dateLine;
                    if (current == null) datesBeforeRecord = true;
                }
                continue;
            }
            if (section.equals("education"))
            {
                Matcher school = SCHOOL.matcher(withoutDates);
                if (school.find())
                {
                    if (range.reset().find()) preservePendingDates(pendingDates, unclassified, warnings);
                    education = new AppResume.Education();
                    education.setSchool(limit(school.group(1), 100));
                    education.setDegree(degreeOf(withoutDates));
                    String remaining = withoutDates.substring(school.end()).replaceFirst("^[\\s|｜,，;；]+", "");
                    String major = remaining.split("[|｜,，;；]|\\s{2,}", 2)[0];
                    major = DEGREE.matcher(major).replaceAll("").replaceFirst("^专业\\s*[:：]\\s*", "").trim();
                    if (!major.isEmpty()) education.setMajor(limit(major, 50));
                    applyDates(range.reset().find() ? dateLine : pendingDates, education, warnings);
                    pendingDates = "";
                    resume.getEducations().add(education);
                    continue;
                }
                if (education != null)
                {
                    if (line.matches("^专业\\s*[:：].+")) education.setMajor(limit(value(line), 50));
                    else if (line.matches("^学历\\s*[:：].+") || DEGREE.matcher(line).matches()) education.setDegree(degreeOf(line));
                    else education.setDescription(append(education.getDescription(), line));
                    continue;
                }
            }
            if (section.equals("work"))
            {
                Matcher company = COMPANY.matcher(withoutDates);
                if (company.find())
                {
                    if (range.reset().find()) preservePendingDates(pendingDates, unclassified, warnings);
                    work = new AppResume.Work();
                    work.setCompany(limit(company.group(1), 100));
                    String position = withoutDates.substring(company.end()).replaceFirst("^[\\s|｜,，;；]+", "");
                    position = position.split("[|｜,，;；]|\\s{2,}", 2)[0].replaceFirst("^(?:职位|岗位)\\s*[:：]\\s*", "");
                    if (!position.isBlank()) work.setPosition(limit(position, 50));
                    applyDates(range.reset().find() ? dateLine : pendingDates, work, warnings);
                    pendingDates = "";
                    resume.getWorks().add(work);
                    continue;
                }
                if (work != null)
                {
                    if (line.matches("^(?:职位|岗位)\\s*[:：].+")) work.setPosition(limit(value(line), 50));
                    else if (line.matches("^部门\\s*[:：].+")) work.setDepartment(limit(value(line), 50));
                    else work.setDescription(append(work.getDescription(), line));
                    continue;
                }
            }
            if (section.equals("project"))
            {
                boolean labeled = withoutDates.matches("^项目名称\\s*[:：].+");
                boolean datedTitle = range.reset().find() && !withoutDates.isBlank() && withoutDates.length() <= 100
                        && !withoutDates.matches("^(?:项目描述|项目职责|职责|成果|技术栈|担任角色)\\s*[:：].*");
                if (labeled || datedTitle || project == null && !withoutDates.contains("：") && !withoutDates.contains(":") && withoutDates.length() <= 80)
                {
                    if (range.reset().find()) preservePendingDates(pendingDates, unclassified, warnings);
                    project = new AppResume.Project();
                    project.setName(limit(labeled ? value(withoutDates) : withoutDates.replaceAll("[|｜\\s]+$", ""), 100));
                    applyDates(range.reset().find() ? dateLine : pendingDates, project, warnings);
                    pendingDates = "";
                    resume.getProjects().add(project);
                    continue;
                }
                if (project != null)
                {
                    if (line.matches("^(?:担任角色|项目角色|角色)\\s*[:：].+")) project.setRole(limit(value(line), 50));
                    else if (line.matches("^(?:技术栈|使用技术|技术或工具)\\s*[:：].+")) project.setTechStack(limit(value(line), 200));
                    else project.setDescription(append(project.getDescription(), line));
                    continue;
                }
            }
            if (section.equals("skill"))
            {
                for (String token : line.split("[,，、;；|｜]"))
                {
                    String name = token.trim();
                    if (name.length() > 0 && name.length() <= 30 && !name.matches(".*[。:：].*")
                            && !name.matches(".*(?:熟悉|熟练|精通|掌握|了解|能够|负责|参与).*") && resume.getSkills().size() < 30)
                    {
                        if (resume.getSkills().stream().noneMatch(item -> name.equals(item.getName())))
                        {
                            AppResume.Skill skill = new AppResume.Skill();
                            skill.setName(name);
                            skill.setLevel(null);
                            resume.getSkills().add(skill);
                        }
                    }
                    else unclassified.add(name);
                }
                continue;
            }
            unclassified.add(line);
        }
        preservePendingDates(pendingDates, unclassified, warnings);
        warnings.add("规则识别按栏目匹配；未明确的学历、职位和技能熟练度不作猜测，请核对原 PDF");
        resume.setUnmappedText(unclassified.isEmpty() ? null : String.join("\n", unclassified));
        resume.setParseWarnings(new ArrayList<>(warnings));
        return resume;
    }

    private String normalizeDateLine(String line)
    {
        return line.replaceFirst("^(?:起止时间|时间|日期|入学时间|毕业时间|开始时间|结束时间|任职时间|项目时间)\\s*[:：]\\s*", "").trim();
    }

    private void preservePendingDates(String pendingDates, List<String> unclassified, Set<String> warnings)
    {
        if (pendingDates == null || pendingDates.isBlank()) return;
        unclassified.add(pendingDates);
        warnings.add("独立日期行没有明确对应的经历，已保留到未归类原文，请核对");
    }

    private boolean hasNoDates(Object target)
    {
        if (target instanceof AppResume.Education item) return item.getStartDate() == null && item.getEndDate() == null;
        if (target instanceof AppResume.Work item) return item.getStartDate() == null && item.getEndDate() == null && !Boolean.TRUE.equals(item.getCurrent());
        if (target instanceof AppResume.Project item) return item.getStartDate() == null && item.getEndDate() == null;
        return false;
    }

    private Integer degreeOf(String line)
    {
        if (line.contains("博士")) return 5;
        if (line.contains("硕士")) return 4;
        if (line.contains("本科") || line.contains("学士")) return 3;
        if (line.contains("大专") || line.contains("专科")) return 2;
        if (line.contains("中专")) return 1;
        return null;
    }

    private void applyDates(String line, Object target, Set<String> warnings)
    {
        Matcher range = RANGE.matcher(line);
        if (!range.find()) return;
        LocalDate start = date(range.group(1), warnings);
        LocalDate end = date(range.group(2), warnings);
        if (start != null && end != null && end.isBefore(start))
        {
            warnings.add("原文起止日期顺序异常，已留空，请手动核对：" + range.group());
            start = null;
            end = null;
        }
        if (target instanceof AppResume.Education item) { item.setStartDate(start); item.setEndDate(end); }
        if (target instanceof AppResume.Work item)
        {
            item.setStartDate(start);
            item.setEndDate(end);
            item.setCurrent(range.group(2).matches("至今|现在|今"));
        }
        if (target instanceof AppResume.Project item) { item.setStartDate(start); item.setEndDate(end); }
    }

    private LocalDate date(String value, Set<String> warnings)
    {
        if (value.matches("至今|现在|今")) return null;
        String[] parts = value.split("\\D+");
        try
        {
            LocalDate date = LocalDate.of(Integer.parseInt(parts[0]), parts.length > 1 ? Integer.parseInt(parts[1]) : 1,
                    parts.length > 2 ? Integer.parseInt(parts[2]) : 1);
            if (parts.length < 3) warnings.add("原文日期精度不足，缺失的月或日补为 01，请核对");
            return date;
        }
        catch (DateTimeException | NumberFormatException exception)
        {
            warnings.add("无效日期已留空，请核对：" + value);
            return null;
        }
    }

    private String value(String line)
    {
        return line.replaceFirst("^[^:：]*[:：]\\s*", "").trim();
    }

    private String append(String previous, String line)
    {
        return previous == null ? line : previous + "\n" + line;
    }

    private String limit(String value, int maximum)
    {
        String trimmed = value.trim();
        return trimmed.length() > maximum ? trimmed.substring(0, maximum) : trimmed;
    }
}
