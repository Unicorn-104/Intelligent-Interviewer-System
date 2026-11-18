package com.ruoyi.enterprise.service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import com.ruoyi.enterprise.domain.EntResumeSnapshot;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ResumeContentHasherTest
{
    private static byte[] pdf(int seed)
    {
        byte[] bytes = new byte[16];
        for (int i = 0; i < bytes.length; i++) bytes[i] = (byte) (seed + i);
        return bytes;
    }

    private EntResumeSnapshot.Education education(String school, String gpa)
    {
        EntResumeSnapshot.Education item = new EntResumeSnapshot.Education();
        item.setSchool(school);
        item.setMajor("软件工程");
        item.setDegree(3);
        item.setStartDate(LocalDate.of(2023, 9, 1));
        item.setEndDate(LocalDate.of(2027, 6, 30));
        item.setGpa(new BigDecimal(gpa));
        item.setDescription("备注");
        return item;
    }

    private EntResumeSnapshot.Work work(String company)
    {
        EntResumeSnapshot.Work item = new EntResumeSnapshot.Work();
        item.setCompany(company);
        item.setPosition("后端开发");
        item.setDepartment("研发部");
        item.setStartDate(LocalDate.of(2025, 7, 1));
        item.setEndDate(null);
        item.setCurrent(Boolean.TRUE);
        item.setSalaryRange("8k-12k");
        item.setDescription("工作内容");
        return item;
    }

    private EntResumeSnapshot.Project project(String name)
    {
        EntResumeSnapshot.Project item = new EntResumeSnapshot.Project();
        item.setName(name);
        item.setRole("核心开发");
        item.setStartDate(LocalDate.of(2026, 3, 1));
        item.setEndDate(LocalDate.of(2026, 8, 1));
        item.setDescription("项目描述");
        item.setTechStack("Java,MySQL");
        return item;
    }

    private EntResumeSnapshot.Skill skill(String name, int level)
    {
        EntResumeSnapshot.Skill item = new EntResumeSnapshot.Skill();
        item.setName(name);
        item.setLevel(level);
        return item;
    }

    private EntResumeSnapshot snapshot(List<EntResumeSnapshot.Education> edu,
            List<EntResumeSnapshot.Work> work, List<EntResumeSnapshot.Project> project,
            List<EntResumeSnapshot.Skill> skill)
    {
        EntResumeSnapshot snapshot = new EntResumeSnapshot();
        snapshot.setResumeName("田清宇的简历");
        snapshot.setJobDirection("Java后端");
        snapshot.setEducations(edu);
        snapshot.setWorks(work);
        snapshot.setProjects(project);
        snapshot.setSkills(skill);
        return snapshot;
    }

    private EntResumeSnapshot full()
    {
        return snapshot(
                List.of(education("贵州大学", "3.50"), education("高中", "3.80")),
                List.of(work("某科技公司")),
                List.of(project("智能招聘系统")),
                List.of(skill("Java", 3), skill("MySQL", 2)));
    }

    @Test
    void hashHasV2PrefixAnd64HexDigest()
    {
        String hash = ResumeContentHasher.hash(full(), pdf(1));
        assertTrue(hash.startsWith(ResumeContentHasher.VERSION_PREFIX));
        String digest = hash.substring(ResumeContentHasher.VERSION_PREFIX.length());
        assertEquals(64, digest.length());
        assertTrue(digest.matches("[0-9a-f]{64}"));
    }

    @Test
    void sameContentWithDifferentSubtableOrderIsEqual()
    {
        EntResumeSnapshot a = full();
        EntResumeSnapshot b = snapshot(
                List.of(education("高中", "3.80"), education("贵州大学", "3.50")),
                List.of(work("某科技公司")),
                List.of(project("智能招聘系统")),
                List.of(skill("MySQL", 2), skill("Java", 3)));
        assertEquals(ResumeContentHasher.hash(a, pdf(1)),
                ResumeContentHasher.hash(b, pdf(1)));
    }

    @Test
    void differentPdfBytesProduceDifferentHash()
    {
        assertNotEquals(ResumeContentHasher.hash(full(), pdf(1)),
                ResumeContentHasher.hash(full(), pdf(2)));
    }

    @Test
    void structuredChangeWithIdenticalPdfProducesDifferentHash()
    {
        EntResumeSnapshot changed = full();
        changed.setSkills(List.of(skill("Java", 4), skill("MySQL", 2)));
        // 核心断言：PDF 完全相同，仅结构化内容变化，哈希必须不同（修复 v1 仅 PDF 哈希缺陷）
        assertNotEquals(ResumeContentHasher.hash(full(), pdf(1)),
                ResumeContentHasher.hash(changed, pdf(1)));
    }

    @Test
    void resumeNameChangeProducesDifferentHash()
    {
        EntResumeSnapshot changed = full();
        changed.setResumeName("另一份简历");
        assertNotEquals(ResumeContentHasher.hash(full(), pdf(1)),
                ResumeContentHasher.hash(changed, pdf(1)));
    }

    @Test
    void gpaTrailingZerosAreNormalized()
    {
        EntResumeSnapshot a = full();
        EntResumeSnapshot b = snapshot(
                List.of(education("贵州大学", "3.5"), education("高中", "3.8")),
                List.of(work("某科技公司")),
                List.of(project("智能招聘系统")),
                List.of(skill("Java", 3), skill("MySQL", 2)));
        assertEquals(ResumeContentHasher.hash(a, pdf(1)),
                ResumeContentHasher.hash(b, pdf(1)));
    }

    @Test
    void nullPdfIsAcceptedAndDistinctFromPresentPdf()
    {
        String nullPdf = ResumeContentHasher.hash(full(), null);
        assertDoesNotThrow(() -> ResumeContentHasher.hash(full(), null));
        assertNotEquals(nullPdf, ResumeContentHasher.hash(full(), pdf(1)));
    }

    @Test
    void emptySubtablesProduceStableHash()
    {
        EntResumeSnapshot empty = snapshot(List.of(), List.of(), List.of(), List.of());
        assertEquals(ResumeContentHasher.hash(empty, pdf(1)),
                ResumeContentHasher.hash(empty, pdf(1)));
    }
}
