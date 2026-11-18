package com.ruoyi.enterprise.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ruoyi.enterprise.domain.EntResumeSnapshot;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 * 企业快照全内容哈希。
 *
 * <p>v1（历史，无前缀）：仅对 PDF 字节做 SHA-256，存在「PDF 不变但结构化内容变化」时哈希相同的缺陷。
 * v2（本类，结果带 "v2:" 前缀）：PDF 字节哈希 + 简历名称/方向 + 教育/工作/项目/技能四子表的规范化表示，
 * 字段顺序固定、子表记录按规范化 JSON 字符串排序、排除自增主键，避免集合顺序与时间格式造成无意义差异。</p>
 */
public final class ResumeContentHasher
{
    /** v2 算法标识前缀，落库后可与 v1（无前缀的 64 位 hex）区分，无需新增列即可识别算法版本。 */
    public static final String VERSION_PREFIX = "v2:";

    private static final String ALGORITHM = "v2";
    private static final DateTimeFormatter ISO_DATE = DateTimeFormatter.ISO_LOCAL_DATE;
    private static final ObjectMapper JSON = new ObjectMapper();

    private ResumeContentHasher() {}

    /**
     * 计算全内容哈希。
     *
     * @param snapshot 已填充主表字段与四子表内容的快照（自增主键不参与哈希）
     * @param pdfBytes 源 PDF 字节；null 表示无 PDF，与「空字节 PDF」区分
     * @return 带 "v2:" 前缀的 SHA-256 十六进制字符串
     */
    public static String hash(EntResumeSnapshot snapshot, byte[] pdfBytes)
    {
        try
        {
            Map<String, Object> root = new LinkedHashMap<>();
            root.put("algorithm", ALGORITHM);
            root.put("pdfSha256", pdfBytes == null ? null : sha256Hex(pdfBytes));
            root.put("resumeName", snapshot.getResumeName());
            root.put("jobDirection", snapshot.getJobDirection());
            root.put("educations", normalize(snapshot.getEducations(), ResumeContentHasher::mapEducation));
            root.put("works", normalize(snapshot.getWorks(), ResumeContentHasher::mapWork));
            root.put("projects", normalize(snapshot.getProjects(), ResumeContentHasher::mapProject));
            root.put("skills", normalize(snapshot.getSkills(), ResumeContentHasher::mapSkill));
            return VERSION_PREFIX + sha256Hex(JSON.writeValueAsBytes(root));
        }
        catch (Exception e)
        {
            throw new IllegalStateException("计算企业快照全内容哈希失败", e);
        }
    }

    /** 每条记录规范化为固定字段 JSON，再按字符串排序，保证集合顺序与数据库返回顺序、自增 ID 无关。 */
    private static <T> List<String> normalize(List<T> items, Function<T, Map<String, Object>> mapper)
    {
        List<String> lines = new ArrayList<>();
        for (T item : items)
        {
            try
            {
                lines.add(JSON.writeValueAsString(mapper.apply(item)));
            }
            catch (Exception e)
            {
                throw new IllegalStateException("规范化简历条目失败", e);
            }
        }
        Collections.sort(lines);
        return lines;
    }

    private static Map<String, Object> mapEducation(EntResumeSnapshot.Education item)
    {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("school", item.getSchool());
        m.put("major", item.getMajor());
        m.put("degree", item.getDegree());
        m.put("startDate", isoDate(item.getStartDate()));
        m.put("endDate", isoDate(item.getEndDate()));
        m.put("gpa", plainDecimal(item.getGpa()));
        m.put("description", item.getDescription());
        return m;
    }

    private static Map<String, Object> mapWork(EntResumeSnapshot.Work item)
    {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("company", item.getCompany());
        m.put("position", item.getPosition());
        m.put("department", item.getDepartment());
        m.put("startDate", isoDate(item.getStartDate()));
        m.put("endDate", isoDate(item.getEndDate()));
        m.put("current", item.getCurrent());
        m.put("salaryRange", item.getSalaryRange());
        m.put("description", item.getDescription());
        return m;
    }

    private static Map<String, Object> mapProject(EntResumeSnapshot.Project item)
    {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("name", item.getName());
        m.put("role", item.getRole());
        m.put("startDate", isoDate(item.getStartDate()));
        m.put("endDate", isoDate(item.getEndDate()));
        m.put("description", item.getDescription());
        m.put("techStack", item.getTechStack());
        return m;
    }

    private static Map<String, Object> mapSkill(EntResumeSnapshot.Skill item)
    {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("name", item.getName());
        m.put("level", item.getLevel());
        return m;
    }

    private static String isoDate(LocalDate date)
    {
        return date == null ? null : date.format(ISO_DATE);
    }

    /** 统一小数表示：去除尾随零，避免 3.50 与 3.5 产生不同哈希。 */
    private static String plainDecimal(BigDecimal value)
    {
        return value == null ? null : value.stripTrailingZeros().toPlainString();
    }

    private static String sha256Hex(byte[] bytes) throws Exception
    {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] hash = digest.digest(bytes);
        StringBuilder sb = new StringBuilder(hash.length * 2);
        for (byte b : hash)
        {
            sb.append(Character.forDigit((b >> 4) & 0xF, 16));
            sb.append(Character.forDigit(b & 0xF, 16));
        }
        return sb.toString();
    }
}
