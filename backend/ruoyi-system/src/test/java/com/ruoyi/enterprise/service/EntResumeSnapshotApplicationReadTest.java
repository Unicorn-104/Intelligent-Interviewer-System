package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.domain.EntResumeSnapshot;
import com.ruoyi.enterprise.mapper.EntResumeSnapshotMapper;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.mapper.app.AppResumeMapper;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;
import com.ruoyi.system.service.storage.S3FileStorage;

/**
 * 投递级简历快照读取（W1/W2）：企业归属校验、快照隔离、不回退 C-App 当前简历、
 * 企业 PDF 独立读取与异常处理。
 */
class EntResumeSnapshotApplicationReadTest
{
    private static final Long COMPANY_ID = 2L;
    private static final Long APP_ID = 100L;

    private EntResumeSnapshotMapper snapshotMapper;
    private AppResumeMapper appResumeMapper;
    private ResumePdfStorage resumePdfStorage;
    private EnterpriseResumeStorage enterpriseStorage;
    private EntResumeSnapshotService service;

    @BeforeEach void setup()
    {
        snapshotMapper = mock(EntResumeSnapshotMapper.class);
        appResumeMapper = mock(AppResumeMapper.class);
        resumePdfStorage = mock(ResumePdfStorage.class);
        enterpriseStorage = mock(EnterpriseResumeStorage.class);
        // 构造函数注入，与生产装配一致
        service = new EntResumeSnapshotService(snapshotMapper, appResumeMapper,
                resumePdfStorage, enterpriseStorage);
    }

    private Map<String, Object> ownership()
    {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("appId", APP_ID);
        map.put("candidateId", 11L);
        map.put("positionId", 30L);
        map.put("status", 1);
        return map;
    }

    private EntResumeSnapshot buildSnapshot()
    {
        EntResumeSnapshot snapshot = new EntResumeSnapshot();
        snapshot.setId(50L);
        snapshot.setAppId(APP_ID);
        snapshot.setCandidateId(11L);
        snapshot.setCompanyId(COMPANY_ID);
        snapshot.setPositionId(30L);
        snapshot.setResumeName("个人简历");
        snapshot.setFileName("个人简历.pdf");
        snapshot.setFilePath("enterprise-application-resume/2/100/abc123.pdf");
        snapshot.setFileSize(12345L);

        EntResumeSnapshot.Education edu = new EntResumeSnapshot.Education();
        edu.setSchool("贵州大学");
        edu.setMajor("软件工程");
        edu.setDegree(3);
        edu.setStartDate(LocalDate.of(2023, 9, 1));
        edu.setEndDate(LocalDate.of(2027, 6, 1));
        snapshot.setEducations(List.of(edu));

        EntResumeSnapshot.Work work = new EntResumeSnapshot.Work();
        work.setCompany("某科技公司");
        work.setPosition("后端工程师");
        work.setCurrent(false);
        work.setStartDate(LocalDate.of(2025, 3, 1));
        work.setEndDate(LocalDate.of(2026, 8, 1));
        work.setDescription("负责后端服务开发");
        snapshot.setWorks(List.of(work));

        EntResumeSnapshot.Project project = new EntResumeSnapshot.Project();
        project.setName("智能招聘系统");
        project.setRole("核心开发");
        project.setTechStack("Java, Flutter");
        project.setDescription("企业端模块开发");
        snapshot.setProjects(List.of(project));

        EntResumeSnapshot.Skill skill = new EntResumeSnapshot.Skill();
        skill.setName("Java");
        skill.setLevel(3);
        snapshot.setSkills(List.of(skill));
        return snapshot;
    }

    @Test void viewReturnsSnapshotWithFrontEndContract()
    {
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(buildSnapshot());

        Map<String, Object> view = service.getApplicationResumeView(COMPANY_ID, APP_ID);

        assertEquals(APP_ID, view.get("applicationId"));
        assertEquals("application_snapshot", view.get("resumeScope"));
        // 路径与大小均有效时，前端入口标记为可展示
        assertEquals(Boolean.TRUE, view.get("hasOriginalPdf"));
        // 快照自身有 PDF 即认定源有文件，无需再查源简历
        assertEquals(Boolean.TRUE, view.get("sourceHasFile"));
        // 前端 TalentResumeSection 期望的四个列表字段
        List<Map> education = castRows(view.get("educationList"));
        List<Map> work = castRows(view.get("workList"));
        List<Map> projects = castRows(view.get("projectList"));
        List<Map> skills = castRows(view.get("skills"));
        assertEquals("贵州大学", education.get(0).get("school"));
        assertEquals("2023-09", education.get(0).get("startDate"));
        assertEquals("某科技公司", work.get(0).get("company"));
        assertEquals("2026-08", work.get(0).get("endDate"));
        assertEquals("负责后端服务开发", work.get(0).get("summary"));
        assertEquals("Java, Flutter", projects.get(0).get("techStack"));
        assertEquals("Java", skills.get(0).get("name"));
        // 投递读取全程不碰 C-App 当前简历
        verifyNoInteractions(appResumeMapper);
    }

    @Test void viewUsesGivenApplicationIdAndDoesNotShareSnapshot()
    {
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(buildSnapshot());

        service.getApplicationResumeView(COMPANY_ID, APP_ID);

        // 严格以传入 applicationId 定位，不同投递不会串用
        verify(snapshotMapper).selectApplicationOwnership(APP_ID, COMPANY_ID);
        verify(snapshotMapper).selectByAppId(APP_ID);
    }

    @Test void viewWithoutPdfPathMarksOriginalPdfUnavailable()
    {
        EntResumeSnapshot snapshot = buildSnapshot();
        snapshot.setFilePath(null);
        snapshot.setFileSize(null);
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(snapshot);

        Map<String, Object> view = service.getApplicationResumeView(COMPANY_ID, APP_ID);
        assertEquals(Boolean.FALSE, view.get("hasOriginalPdf"));
        // 无源简历标识时不查源，按未提供处理
        assertEquals(Boolean.FALSE, view.get("sourceHasFile"));
    }

    @Test void viewWithZeroSizeMarksOriginalPdfUnavailable()
    {
        EntResumeSnapshot snapshot = buildSnapshot();
        snapshot.setFileSize(0L);
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(snapshot);

        Map<String, Object> view = service.getApplicationResumeView(COMPANY_ID, APP_ID);
        assertEquals(Boolean.FALSE, view.get("hasOriginalPdf"));
        // 大小为 0 同样视为无 PDF；无源简历标识不查源，按未提供处理
        assertEquals(Boolean.FALSE, view.get("sourceHasFile"));
    }

    @Test void viewWithoutSnapshotPdfButSourceHasFileMarksSourceOnly()
    {
        EntResumeSnapshot snapshot = buildSnapshot();
        snapshot.setFilePath(null);
        snapshot.setFileSize(null);
        snapshot.setSourceResumeId(38L);
        // 源简历（含已停用情形）存在有效文件
        AppResume sourceResume = new AppResume();
        sourceResume.setFilePath("private-resume/104/2026/10/28/x.pdf");
        sourceResume.setFileSize(360830L);
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(snapshot);
        when(appResumeMapper.selectResumeFileById(38L)).thenReturn(sourceResume);

        Map<String, Object> view = service.getApplicationResumeView(COMPANY_ID, APP_ID);

        // 快照无 PDF 但源有文件：前端据此显示「简历附件暂不可用」而非「未提供」
        assertEquals(Boolean.FALSE, view.get("hasOriginalPdf"));
        assertEquals(Boolean.TRUE, view.get("sourceHasFile"));
        verify(appResumeMapper).selectResumeFileById(38L);
        // 必须使用不限制状态的查询，不能误用带状态过滤的方法
        verify(appResumeMapper, never()).selectResumeById(any());
    }

    @Test void viewWithoutSnapshotPdfAndSourceNoFileMarksNotProvided()
    {
        EntResumeSnapshot snapshot = buildSnapshot();
        snapshot.setFilePath(null);
        snapshot.setFileSize(null);
        snapshot.setSourceResumeId(16L);
        AppResume sourceResume = new AppResume();
        sourceResume.setFilePath(null);
        sourceResume.setFileSize(null);
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(snapshot);
        when(appResumeMapper.selectResumeFileById(16L)).thenReturn(sourceResume);

        Map<String, Object> view = service.getApplicationResumeView(COMPANY_ID, APP_ID);

        // 源简历也无文件：前端据此显示「未提供简历附件」
        assertEquals(Boolean.FALSE, view.get("hasOriginalPdf"));
        assertEquals(Boolean.FALSE, view.get("sourceHasFile"));
    }

    @Test void viewSourceResumeMissingMarksNotProvided()
    {
        EntResumeSnapshot snapshot = buildSnapshot();
        snapshot.setFilePath(null);
        snapshot.setFileSize(null);
        snapshot.setSourceResumeId(99L);
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(snapshot);
        when(appResumeMapper.selectResumeFileById(99L)).thenReturn(null);

        Map<String, Object> view = service.getApplicationResumeView(COMPANY_ID, APP_ID);

        // 源简历查不到时不臆测，按未提供处理
        assertEquals(Boolean.FALSE, view.get("sourceHasFile"));
    }

    @Test void crossCompanyAccessIsRejectedBeforeSnapshotRead()
    {
        // 归属校验返回 null：投递不存在或不属于当前企业
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(null);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getApplicationResumeView(COMPANY_ID, APP_ID));
        assertEquals("无权访问该投递或投递不存在", error.getMessage());
        // 拒绝后不读取快照、不读 C-App 数据
        verify(snapshotMapper, never()).selectByAppId(any());
        verifyNoInteractions(appResumeMapper, enterpriseStorage);
    }

    @Test void missingSnapshotThrowsNotAvailableWithoutCurrentResumeFallback()
    {
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(null);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getApplicationResumeView(COMPANY_ID, APP_ID));
        assertTrue(error.getMessage().contains("SNAPSHOT_NOT_AVAILABLE"));
        assertEquals(S3FileStorage.NOT_FOUND_CODE, error.getCode());
        // 快照缺失不回退 C-App 当前简历
        verifyNoInteractions(appResumeMapper);
    }

    @Test void pdfReadsEnterpriseStorageWithoutRbsStatus()
    {
        Resource pdf = new ByteArrayResource(new byte[] {1, 2, 3});
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(buildSnapshot());
        when(enterpriseStorage.read("enterprise-application-resume/2/100/abc123.pdf"))
                .thenReturn(pdf);

        AppResumePdfDocument document =
                service.getApplicationResumePdf(COMPANY_ID, APP_ID);

        assertSame(pdf, document.resource());
        assertEquals("个人简历.pdf", document.name());
        verify(enterpriseStorage).read("enterprise-application-resume/2/100/abc123.pdf");
        // 企业 PDF 不依赖 C-App 简历状态与私有存储
        verifyNoInteractions(appResumeMapper, resumePdfStorage);
    }

    @Test void pdfBlankPathIsExplainedWithoutReadingStorage()
    {
        EntResumeSnapshot snapshot = buildSnapshot();
        snapshot.setFilePath(" ");
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(snapshot);

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getApplicationResumePdf(COMPANY_ID, APP_ID));
        assertEquals("该投递原始 PDF 不可用", error.getMessage());
        verifyNoInteractions(enterpriseStorage);
    }

    @Test void pdfMissingObjectIsExplainedWithoutFallback()
    {
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(ownership());
        when(snapshotMapper.selectByAppId(APP_ID)).thenReturn(buildSnapshot());
        when(enterpriseStorage.read(anyString()))
                .thenThrow(new ServiceException("企业简历 PDF 不存在",
                        S3FileStorage.NOT_FOUND_CODE));

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.getApplicationResumePdf(COMPANY_ID, APP_ID));
        assertEquals("原始简历文件缺失，请联系管理员核实", error.getMessage());
        assertEquals(S3FileStorage.NOT_FOUND_CODE, error.getCode());
        // 不回退 C-App 当前 PDF
        verifyNoInteractions(resumePdfStorage, appResumeMapper);
    }

    @Test void pdfCrossCompanyAccessIsRejected()
    {
        when(snapshotMapper.selectApplicationOwnership(APP_ID, COMPANY_ID))
                .thenReturn(null);

        assertThrows(ServiceException.class,
                () -> service.getApplicationResumePdf(COMPANY_ID, APP_ID));
        verify(snapshotMapper, never()).selectByAppId(any());
        verifyNoInteractions(enterpriseStorage);
    }

    @SuppressWarnings("unchecked")
    private List<Map> castRows(Object value)
    {
        return (List<Map>) value;
    }
}
