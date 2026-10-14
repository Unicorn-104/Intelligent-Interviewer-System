package com.ruoyi.system.service.app.pdf;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.DateTimeException;
import java.util.ArrayList;
import java.util.List;
import java.util.LinkedHashSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.MissingNode;
import com.ruoyi.system.domain.app.AppResume;

/** AI 内容宽松映射到已有字段；局部无法转换时保留原值，其他经历继续填充。 */
final class ResumeAiFieldMapper
{
    private static final Pattern DATE = Pattern.compile("^(\\d{4})(?:[-/.年](\\d{1,2})(?!\\d))?(?:[-/.月](\\d{1,2})(?!\\d))?[年月日]?(?:T.*)?$");
    private final List<String> notes = new ArrayList<>();
    private final List<String> extra = new ArrayList<>();
    private final ObjectMapper json = new ObjectMapper();

    AppResume map(JsonNode root)
    {
        if (root == null) throw new IllegalArgumentException("Resume JSON is empty");
        if (root.isArray() && root.size() > 0) root = root.get(0);
        for (int depth = 0; depth < 4; depth++)
        {
            JsonNode nested = pick(root, "resume", "data", "result", "resumeData", "structuredResume", "简历");
            if (!nested.isObject()) break;
            root = nested;
        }
        if (!root.isObject()) throw new IllegalArgumentException("Resume JSON must contain an object");
        AppResume resume = new AppResume();
        resume.setJobDirection(text(pick(root, "jobDirection", "rbs_job_direction", "job_direction", "targetRole", "job_intention", "求职意向", "期望职位"), 50, "求职方向"));
        addExtra(pick(root, "unmappedText", "unmapped_text", "additionalInfo", "其他信息", "未映射内容"), null);
        for (JsonNode warning : list(pick(root, "warnings", "parseWarnings", "提示")))
            if (!warning.isNull()) notes.add(raw(warning));
        for (JsonNode node : list(pick(root, "educations", "t_res_education", "education_history", "education", "educationExperience", "educationExperiences", "education_experiences", "教育经历", "教育背景")))
        {
            AppResume.Education item = new AppResume.Education();
            item.setSchool(text(pick(node, "school", "schoolName", "university", "edu_school", "学校", "学校名称"), 100, "学校"));
            item.setMajor(text(pick(node, "major", "specialty", "edu_major", "专业"), 50, "专业"));
            JsonNode degree = pick(node, "degree", "edu_degree", "educationLevel", "学历");
            item.setDegree(enumValue(degree, true));
            item.setStartDate(date(pick(node, "startDate", "start_date", "入学时间", "开始时间"), "入学时间"));
            item.setEndDate(date(pick(node, "endDate", "end_date", "毕业时间", "结束时间"), "毕业时间"));
            String description = text(pick(node, "description", "courses", "edu_description", "描述", "课程"), 4000, "教育描述");
            JsonNode gpa = pick(node, "gpa", "edu_gpa", "GPA", "成绩", "绩点");
            item.setGpa(decimal(gpa));
            if (!degree.isMissingNode() && item.getDegree() == null)
                description = append(description, "学历：" + raw(degree));
            if (!gpa.isMissingNode() && item.getGpa() == null)
                description = append(description, "成绩：" + raw(gpa));
            if (node.isTextual()) description = raw(node);
            item.setDescription(textValue(description, 4000, "教育描述"));
            checkDates(item.getStartDate(), item.getEndDate());
            resume.getEducations().add(item);
        }
        for (JsonNode node : list(pick(root, "works", "t_res_work", "work_history", "work", "workExperience", "workExperiences", "work_experience", "employment", "工作经历", "实习经历")))
        {
            AppResume.Work item = new AppResume.Work();
            item.setCompany(text(pick(node, "company", "companyName", "employer", "wrk_company", "公司", "公司名称"), 100, "公司"));
            item.setPosition(text(pick(node, "position", "jobTitle", "title", "wrk_position", "职位", "岗位"), 50, "职位"));
            item.setDepartment(text(pick(node, "department", "部门"), 50, "部门"));
            item.setStartDate(date(pick(node, "startDate", "start_date", "入职时间", "开始时间"), "入职时间"));
            JsonNode end = pick(node, "endDate", "end_date", "离职时间", "结束时间");
            boolean current = present(end) || bool(pick(node, "current", "wrk_is_current", "isCurrent", "is_current", "在职"));
            item.setCurrent(current);
            item.setEndDate(current ? null : date(end, "离职时间"));
            item.setSalaryRange(text(pick(node, "salaryRange", "wrk_salary_range", "salary", "薪资"), 20, "薪资"));
            item.setDescription(text(node.isTextual() ? node : pick(node, "description", "wrk_description", "responsibilities", "achievements", "工作内容", "描述", "职责"), 4000, "工作描述"));
            checkDates(item.getStartDate(), item.getEndDate());
            resume.getWorks().add(item);
        }
        for (JsonNode node : list(pick(root, "projects", "t_res_project", "project", "projectExperience", "projectExperiences", "project_experience", "项目经历", "项目经验")))
        {
            AppResume.Project item = new AppResume.Project();
            item.setName(text(pick(node, "name", "projectName", "title", "prj_name", "项目名称", "名称"), 100, "项目名称"));
            item.setRole(text(pick(node, "role", "prj_role", "position", "担任角色", "角色"), 50, "项目角色"));
            item.setStartDate(date(pick(node, "startDate", "start_date", "开始时间"), "项目开始时间"));
            item.setEndDate(date(pick(node, "endDate", "end_date", "结束时间"), "项目结束时间"));
            item.setDescription(text(node.isTextual() ? node : pick(node, "description", "prj_description", "details", "项目描述", "描述"), 4000, "项目描述"));
            item.setTechStack(text(pick(node, "techStack", "prj_tech_stack", "tech_stack", "technologies", "技术栈"), 200, "技术栈"));
            checkDates(item.getStartDate(), item.getEndDate());
            resume.getProjects().add(item);
        }
        JsonNode skills = pick(root, "skills", "t_res_skill", "skill", "skillTags", "skill_tags", "技能", "专业技能");
        if (skills.isTextual())
        {
            for (String name : skills.asText().split("[,，、;；\\n]+"))
            {
                if (name.isBlank()) continue;
                AppResume.Skill item = new AppResume.Skill();
                item.setName(textValue(name, 50, "技能"));
                item.setLevel(null);
                resume.getSkills().add(item);
            }
        }
        else for (JsonNode node : list(skills))
        {
            AppResume.Skill item = new AppResume.Skill();
            item.setName(text(node.isTextual() ? node : pick(node, "name", "skl_name", "skillName", "技能名称", "技能"), 50, "技能"));
            item.setLevel(enumValue(pick(node, "level", "skl_level", "proficiency", "熟练度"), false));
            resume.getSkills().add(item);
        }
        resume.setStructureMethod("AI");
        resume.setParseWarnings(new ArrayList<>(new LinkedHashSet<>(notes)));
        resume.setUnmappedText(extra.isEmpty() ? null : String.join("\n", extra));
        // 用户、简历和附件标识不从 AI 结果读取，即使模型额外输出这些字段也不会被采用。
        return resume;
    }

    private JsonNode pick(JsonNode node, String... keys)
    {
        if (node == null || !node.isObject()) return MissingNode.getInstance();
        for (String key : keys)
        {
            JsonNode value = node.get(key);
            if (usable(value)) return value;
        }
        return MissingNode.getInstance();
    }

    private boolean usable(JsonNode node)
    {
        return node != null && !node.isNull() && !node.isMissingNode()
                && !(node.isTextual() && node.asText().isBlank()) && !(node.isArray() && node.isEmpty());
    }

    private List<JsonNode> list(JsonNode node)
    {
        List<JsonNode> result = new ArrayList<>();
        if (!usable(node)) return result;
        if (node.isArray()) node.forEach(item -> { if (!item.isNull()) result.add(item); });
        else if (node.isObject())
        {
            JsonNode nested = pick(node, "items", "list", "records");
            if (nested.isArray()) nested.forEach(result::add);
            else result.add(node);
        }
        else if (node.isTextual())
        {
            String value = node.asText().trim();
            if (value.startsWith("[") || value.startsWith("{"))
            {
                try { return list(json.readTree(value)); } catch (Exception ignored) { }
            }
            result.add(node);
        }
        return result;
    }

    private String text(JsonNode node, int max, String field) { return textValue(raw(node), max, field); }

    private String textValue(String value, int max, String field)
    {
        if (value == null || value.isBlank()) return null;
        value = value.trim();
        if (value.length() <= max) return value;
        extra.add(field + "：" + value);
        notes.add(field + "较长，完整内容已保留在未映射内容和原 PDF 中");
        int end = Character.isHighSurrogate(value.charAt(max - 1)) ? max - 1 : max;
        return value.substring(0, end);
    }

    private String raw(JsonNode node)
    {
        if (!usable(node)) return null;
        if (node.isValueNode()) return node.asText();
        if (node.isArray())
        {
            List<String> values = new ArrayList<>();
            node.forEach(value -> { String text = raw(value); if (text != null) values.add(text); });
            return String.join("、", values);
        }
        return node.toString();
    }

    private Integer enumValue(JsonNode node, boolean degree)
    {
        String value = raw(node);
        if (value == null) return null;
        try
        {
            int number = new BigDecimal(value.trim()).intValueExact();
            if (number >= 1 && number <= (degree ? 5 : 4)) return number;
        }
        catch (NumberFormatException | ArithmeticException ignored) { }
        String normalized = value.toLowerCase();
        if (degree)
        {
            if (normalized.contains("博士") || normalized.contains("phd") || normalized.contains("doctor")) return 5;
            if (normalized.contains("硕士") || normalized.contains("master")) return 4;
            if (normalized.contains("本科") || normalized.contains("学士") || normalized.contains("bachelor")) return 3;
            if (normalized.contains("大专") || normalized.contains("专科") || normalized.contains("associate")) return 2;
            if (normalized.contains("中专")) return 1;
        }
        else
        {
            if (normalized.contains("专家") || normalized.contains("expert")) return 4;
            if (normalized.contains("精通") || normalized.contains("proficient")) return 3;
            if (normalized.contains("熟悉") || normalized.contains("familiar")) return 2;
            if (normalized.contains("了解") || normalized.contains("basic")) return 1;
        }
        addExtra(node, degree ? "学历" : "技能熟练度");
        return null;
    }

    private BigDecimal decimal(JsonNode node)
    {
        String value = raw(node);
        if (value == null) return null;
        try
        {
            BigDecimal number = new BigDecimal(value.trim().split("/", 2)[0]).setScale(2, RoundingMode.HALF_UP);
            if (number.signum() >= 0 && number.compareTo(new BigDecimal("9.99")) <= 0) return number;
        }
        catch (NumberFormatException ignored) { }
        addExtra(node, "成绩");
        return null;
    }

    private LocalDate date(JsonNode node, String field)
    {
        String value = raw(node);
        if (value == null || present(node)) return null;
        Matcher match = DATE.matcher(value.trim().replaceAll("\\s", ""));
        if (match.matches())
        {
            try
            {
                int year = Integer.parseInt(match.group(1));
                if (year >= 1000 && year <= 9999)
                    return LocalDate.of(year, match.group(2) == null ? 1 : Integer.parseInt(match.group(2)),
                            match.group(3) == null ? 1 : Integer.parseInt(match.group(3)));
            }
            catch (DateTimeException ignored) { }
        }
        addExtra(node, field);
        notes.add(field + "未能转换，其他已编排内容已保留");
        return null;
    }

    private boolean present(JsonNode node)
    {
        String text = raw(node);
        return text != null && (text.contains("至今") || text.equalsIgnoreCase("present") || text.equalsIgnoreCase("now"));
    }

    private boolean bool(JsonNode node)
    {
        if (node.isBoolean()) return node.booleanValue();
        String value = raw(node);
        return value != null && List.of("true", "1", "是", "在职", "至今", "yes").contains(value.trim().toLowerCase());
    }

    private void checkDates(LocalDate start, LocalDate end)
    {
        if (start != null && end != null && start.isAfter(end)) notes.add("经历时间顺序需核对，原日期已保留");
    }

    private void addExtra(JsonNode node, String label)
    {
        String value = raw(node);
        if (value != null) extra.add(label == null ? value : label + "：" + value);
    }

    private String append(String text, String note) { return text == null ? note : text + "\n" + note; }
}
