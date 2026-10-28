package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.github.pagehelper.PageHelper;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.TalentPoolMapper;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.app.AppResumeMapper;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;

/** 企业端查看候选人原始简历 PDF 的归属校验与授权读取。 */
class TalentPoolResumePdfTest
{
    TalentPoolServiceImpl service;
    TalentPoolMapper mapper;
    DashboardMapper dashboard;
    AppResumeMapper resumeMapper;
    ResumePdfStorage storage;

    @BeforeEach void setup()
    {
        service = new TalentPoolServiceImpl();
        mapper = mock(TalentPoolMapper.class);
        dashboard = mock(DashboardMapper.class);
        resumeMapper = mock(AppResumeMapper.class);
        storage = mock(ResumePdfStorage.class);
        ReflectionTestUtils.setField(service, "talentPoolMapper", mapper);
        ReflectionTestUtils.setField(service, "dashboardMapper", dashboard);
        ReflectionTestUtils.setField(service, "appResumeMapper", resumeMapper);
        ReflectionTestUtils.setField(service, "resumePdfStorage", storage);
        when(dashboard.selectCompanyIdByUser(9L)).thenReturn(2L);
    }

    private Map<String, Object> talent(Long resumeId, Long userId)
    {
        Map<String, Object> talent = new LinkedHashMap<>();
        talent.put("talentId", 11L);
        talent.put("resumeId", resumeId);
        talent.put("userId", userId);
        return talent;
    }

    private AppResume resume(Long userId, String filePath)
    {
        AppResume resume = new AppResume();
        resume.setResumeId(5L);
        resume.setUserId(userId);
        resume.setFilePath(filePath);
        resume.setFileName("个人简历.pdf");
        return resume;
    }

    @Test void talentOutsideCompanyIsRejectedBeforeAnyFileRead()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(null);
        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getTalentResumePdf(9L, 11L));
        assertEquals("候选人不存在", error.getMessage());
        verifyNoInteractions(resumeMapper, storage);
    }

    @Test void talentWithoutLinkedResumeIsExplained()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent(null, 7L));
        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getTalentResumePdf(9L, 11L));
        assertEquals("该候选人暂无关联简历", error.getMessage());
        verifyNoInteractions(resumeMapper, storage);
    }

    @Test void invalidCandidateAccountIsRejected()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent(5L, null));
        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getTalentResumePdf(9L, 11L));
        assertEquals("候选人账号无效，无法读取原始简历", error.getMessage());
        verifyNoInteractions(resumeMapper, storage);
    }

    @Test void resumeOwnedBySomeoneElseIsRejected()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent(5L, 7L));
        when(resumeMapper.selectResumeById(5L)).thenReturn(resume(8L, "private-resume/8/2026/10/27/a.pdf"));
        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getTalentResumePdf(9L, 11L));
        assertEquals("简历不存在或无权访问", error.getMessage());
        verifyNoInteractions(storage);
    }

    @Test void missingAttachmentIsExplainedWithoutTouchingDisk()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent(5L, 7L));
        when(resumeMapper.selectResumeById(5L)).thenReturn(resume(7L, " "));
        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getTalentResumePdf(9L, 11L));
        assertEquals("该简历未保存原始 PDF", error.getMessage());
        verifyNoInteractions(storage);
    }

    @Test void authorizedTalentReadsCandidateFileWithOriginalName()
    {
        Path file = Path.of("synthetic", "resume.pdf");
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent(5L, 7L));
        when(resumeMapper.selectResumeById(5L)).thenReturn(resume(7L, "private-resume/7/2026/10/27/a.pdf"));
        when(storage.read(7L, "private-resume/7/2026/10/27/a.pdf")).thenReturn(file);
        AppResumePdfDocument document = service.getTalentResumePdf(9L, 11L);
        assertEquals(file, document.path());
        assertEquals("个人简历.pdf", document.name());
        verify(storage).read(7L, "private-resume/7/2026/10/27/a.pdf");
    }

    @Test void parsedResumeExposesFileNameOnlyWhenAttachmentExists()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent(5L, 7L));
        stubResumeRows();
        when(resumeMapper.selectResumeById(5L)).thenReturn(resume(7L, "private-resume/7/2026/10/27/a.pdf"));
        Map<String, Object> withFile = service.getTalentResume(9L, 11L);
        assertEquals("个人简历.pdf", withFile.get("fileName"));

        when(resumeMapper.selectResumeById(5L)).thenReturn(resume(7L, null));
        Map<String, Object> withoutFile = service.getTalentResume(9L, 11L);
        assertNull(withoutFile.get("fileName"));
        assertEquals(withFile.get("integrity"), withoutFile.get("integrity")); // 结构数据不受附件影响
        PageHelper.clearPage();
    }

    @Test void parsedResumeKeepsNullFileNameWhenNoLinkedResume()
    {
        when(mapper.selectTalentById(2L, 11L)).thenReturn(talent(null, 7L));
        Map<String, Object> result = service.getTalentResume(9L, 11L);
        assertNull(result.get("fileName"));
        PageHelper.clearPage();
    }

    private void stubResumeRows()
    {
        when(mapper.selectEducation(5L)).thenReturn(List.of());
        when(mapper.selectWork(5L)).thenReturn(List.of());
        when(mapper.selectProject(5L)).thenReturn(List.of());
        when(mapper.selectSkill(5L)).thenReturn(List.of());
    }
}
