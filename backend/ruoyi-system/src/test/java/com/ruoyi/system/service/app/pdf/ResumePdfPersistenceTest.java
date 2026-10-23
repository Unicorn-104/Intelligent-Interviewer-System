package com.ruoyi.system.service.app.pdf;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.ResumePdfProperties;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.mapper.app.AppResumeMapper;
import com.ruoyi.system.service.app.IAppResumeService;
import com.ruoyi.system.service.app.impl.AppResumeServiceImpl;
import static org.junit.jupiter.api.Assertions.*;

class ResumePdfPersistenceTest
{
    @TempDir Path directory;
    private IAppResumeService service;
    private ResumePdfStorage storage;
    private JdbcTemplate jdbc;
    private AppResumeMapper mapper;

    @BeforeEach
    void setup() throws Exception
    {
        new RuoYiConfig().setProfile(directory.resolve("public-upload").toString());
        DriverManagerDataSource source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(source);
        jdbc.execute("""
            create table t_res_base (rbs_id bigint auto_increment primary key, rbs_user_id bigint,
                rbs_resume_name varchar(100), rbs_job_direction varchar(50), rbs_is_default boolean,
                rbs_status int, rbs_updated_at timestamp default current_timestamp,
                rbs_file_path varchar(500), rbs_file_name varchar(255), rbs_file_size bigint)
            """);
        jdbc.execute("""
            create table t_res_education (edu_id bigint auto_increment primary key, edu_resume_id bigint,
                edu_school varchar(100), edu_major varchar(50), edu_degree int, edu_start_date date,
                edu_end_date date, edu_gpa decimal(5,2), edu_description varchar(2000))
            """);
        jdbc.execute("""
            create table t_res_work (wrk_id bigint auto_increment primary key, wrk_resume_id bigint,
                wrk_company varchar(100), wrk_position varchar(50), wrk_department varchar(100),
                wrk_start_date date, wrk_end_date date, wrk_is_current boolean, wrk_salary_range varchar(50),
                wrk_description varchar(2000))
            """);
        jdbc.execute("""
            create table t_res_project (prj_id bigint auto_increment primary key, prj_resume_id bigint,
                prj_name varchar(100) check (prj_name <> 'FAIL'), prj_role varchar(50), prj_start_date date,
                prj_end_date date, prj_description varchar(2000), prj_tech_stack varchar(500))
            """);
        jdbc.execute("create table t_res_skill (skl_id bigint auto_increment primary key, skl_resume_id bigint, skl_name varchar(50), skl_level int)");
        jdbc.execute("create table t_app_record (app_id bigint auto_increment primary key, app_resume_id bigint)");
        jdbc.execute("create table t_tal (tal_id bigint auto_increment primary key, tal_resume_id bigint)");
        SqlSessionFactoryBean factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        org.apache.ibatis.session.Configuration configuration = new org.apache.ibatis.session.Configuration();
        configuration.setMapUnderscoreToCamelCase(true);
        factory.setConfiguration(configuration);
        factory.setMapperLocations(new ClassPathResource("mapper/app/AppResumeMapper.xml"));
        mapper = new SqlSessionTemplate(factory.getObject()).getMapper(AppResumeMapper.class);
        ResumePdfProperties props = new ResumePdfProperties();
        storage = new ResumePdfStorage(props);
        AppResumeServiceImpl target = new AppResumeServiceImpl();
        ReflectionTestUtils.setField(target, "resumeMapper", mapper);
        ReflectionTestUtils.setField(target, "pdfParser", new LocalResumePdfParser(props));
        ReflectionTestUtils.setField(target, "pdfStorage", storage);
        ProxyFactory proxy = new ProxyFactory(target);
        proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(source),
                new AnnotationTransactionAttributeSource()));
        service = (IAppResumeService) proxy.getProxy();
    }

    private AppResume draft()
    {
        AppResume resume = new AppResume();
        resume.setResumeName("Synthetic resume");
        resume.setJobDirection("Java developer");
        AppResume.Education education = new AppResume.Education();
        education.setSchool("Synthetic University");
        education.setDegree(3);
        resume.getEducations().add(education);
        return resume;
    }

    private long fileCount() throws Exception
    {
        try (Stream<Path> files = Files.walk(directory))
        {
            return files.filter(path -> path.toString().endsWith(".pdf")).count();
        }
    }

    @Test
    void manualResumeWithoutPdfStillCreatesAndEditsNormally() throws Exception
    {
        AppResume saved = service.saveResume(17L, draft());
        assertNull(saved.getFilePath());
        assertNull(saved.getFileSize());
        assertNull(saved.getPdfUrl());
        saved.setResumeName("Manually edited resume");
        AppResume edited = service.saveResume(17L, saved);
        assertEquals("Manually edited resume", edited.getResumeName());
        assertNull(edited.getFileSize());
        assertEquals(0, fileCount());
    }

    @Test
    void savesOriginalBytesAndMetadataWithStructuredDetails() throws Exception
    {
        byte[] bytes = LocalResumePdfParserTest.textPdf(1);
        AppResume saved = service.saveResumeWithPdf(17L, draft(), bytes, "简历.pdf");
        assertEquals("简历.pdf", saved.getFileName());
        assertEquals(bytes.length, saved.getFileSize());
        assertEquals("/app/resumes/" + saved.getResumeId() + "/pdf", saved.getPdfUrl());
        assertEquals(1, saved.getEducations().size());
        assertArrayEquals(bytes, Files.readAllBytes(service.selectPdf(17L, saved.getResumeId()).path()));
        assertEquals(saved.getFilePath(), jdbc.queryForObject("select rbs_file_path from t_res_base", String.class));
        assertThrows(ServiceException.class, () -> service.selectPdf(18L, saved.getResumeId()));
        assertEquals(1, fileCount());
    }

    @Test
    void ordinaryEditKeepsOriginalAndRejectsSubmittedMetadata() throws Exception
    {
        AppResume saved = service.saveResumeWithPdf(17L, draft(), LocalResumePdfParserTest.textPdf(1), "original.pdf");
        String reference = saved.getFilePath();
        saved.setFilePath("../../another-user.pdf");
        saved.setFileName("forged.pdf");
        saved.setFileSize(1L);
        saved.setResumeName("Edited name");
        AppResume edited = service.saveResume(17L, saved);
        assertEquals(reference, edited.getFilePath());
        assertEquals("original.pdf", edited.getFileName());
        assertEquals("Edited name", edited.getResumeName());
        assertEquals(1, fileCount());
    }

    @Test
    void replacementRemovesOldFileOnlyAfterSuccessfulCommit() throws Exception
    {
        AppResume saved = service.saveResumeWithPdf(17L, draft(), LocalResumePdfParserTest.textPdf(1), "old.pdf");
        Path old = storage.read(17L, saved.getFilePath());
        AppResume updated = service.saveResumeWithPdf(17L, saved, LocalResumePdfParserTest.textPdf(2), "new.pdf");
        assertFalse(Files.exists(old));
        assertEquals("new.pdf", updated.getFileName());
        assertEquals(1, fileCount());
    }

    @Test
    void failedCreateRollsBackDatabaseAndDeletesNewFile() throws Exception
    {
        AppResume draft = draft();
        AppResume.Project project = new AppResume.Project();
        project.setName("FAIL");
        draft.getProjects().add(project);
        byte[] bytes = LocalResumePdfParserTest.textPdf(1);
        assertThrows(RuntimeException.class, () -> service.saveResumeWithPdf(17L, draft, bytes, "failed.pdf"));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_res_base", Integer.class));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_res_education", Integer.class));
        assertEquals(0, fileCount());
    }

    @Test
    void failedReplacementRetainsOldMetadataAndBytes() throws Exception
    {
        AppResume saved = service.saveResumeWithPdf(17L, draft(), LocalResumePdfParserTest.textPdf(1), "old.pdf");
        Path old = storage.read(17L, saved.getFilePath());
        AppResume.Project project = new AppResume.Project();
        project.setName("FAIL");
        saved.getProjects().add(project);
        byte[] bytes = LocalResumePdfParserTest.textPdf(2);
        assertThrows(RuntimeException.class, () -> service.saveResumeWithPdf(17L, saved, bytes, "new.pdf"));
        assertTrue(Files.exists(old));
        assertEquals("old.pdf", mapper.selectResume(saved.getResumeId(), 17L).getFileName());
        assertEquals(1, fileCount());
    }

    @Test
    void otherUserCannotReplaceOrResolveOriginal() throws Exception
    {
        AppResume saved = service.saveResumeWithPdf(17L, draft(), LocalResumePdfParserTest.textPdf(1), "owner.pdf");
        byte[] bytes = LocalResumePdfParserTest.textPdf(1);
        assertThrows(ServiceException.class, () -> service.saveResumeWithPdf(18L, saved, bytes, "intruder.pdf"));
        assertThrows(ServiceException.class, () -> storage.read(18L, saved.getFilePath()));
        assertThrows(ServiceException.class, () -> storage.read(17L, "private-resume/17/../../outside.pdf"));
        assertEquals(1, fileCount());
    }

    @Test
    void deletesUnreferencedResumeAndItsPrivatePdfAfterCommit() throws Exception
    {
        AppResume first = service.saveResumeWithPdf(17L, draft(), LocalResumePdfParserTest.textPdf(1), "first.pdf");
        AppResume second = service.saveResume(17L, draft());
        Path deletedFile = storage.read(17L, first.getFilePath());

        assertEquals(1, service.deleteResume(17L, first.getResumeId()));

        assertFalse(Files.exists(deletedFile));
        assertEquals(0, fileCount());
        assertNull(mapper.selectResume(first.getResumeId(), 17L));
        assertEquals(second.getResumeId(), jdbc.queryForObject(
                "select rbs_id from t_res_base where rbs_status = 1 and rbs_is_default = true", Long.class));
        assertEquals(0, jdbc.queryForObject("select count(*) from t_res_education where edu_resume_id = ?",
                Integer.class, first.getResumeId()));
        assertEquals(0, jdbc.queryForObject("select rbs_status from t_res_base where rbs_id = ?",
                Integer.class, first.getResumeId()));
    }

    @Test
    void refusesDeletingResumeReferencedByApplicationOrTalentRecord() throws Exception
    {
        AppResume saved = service.saveResumeWithPdf(17L, draft(), LocalResumePdfParserTest.textPdf(1), "used.pdf");
        Path file = storage.read(17L, saved.getFilePath());
        jdbc.update("insert into t_app_record (app_resume_id) values (?)", saved.getResumeId());

        ServiceException error = assertThrows(ServiceException.class,
                () -> service.deleteResume(17L, saved.getResumeId()));

        assertEquals("该简历已关联投递记录，暂不能删除", error.getMessage());
        assertTrue(Files.exists(file));
        assertNotNull(mapper.selectResume(saved.getResumeId(), 17L));

        jdbc.update("delete from t_app_record");
        jdbc.update("insert into t_tal (tal_resume_id) values (?)", saved.getResumeId());
        assertThrows(ServiceException.class, () -> service.deleteResume(17L, saved.getResumeId()));
        assertTrue(Files.exists(file));
        assertEquals(1, fileCount());
    }

    @Test
    void anotherUserCannotDeleteResume() throws Exception
    {
        AppResume saved = service.saveResume(17L, draft());
        assertThrows(ServiceException.class, () -> service.deleteResume(18L, saved.getResumeId()));
        assertNotNull(mapper.selectResume(saved.getResumeId(), 17L));
    }

    @Test
    void rejectsPublicStorageDirectory() throws Exception
    {
        ResumePdfProperties props = new ResumePdfProperties();
        props.setStorageDirectory(directory.resolve("public-upload/resume").toString());
        ResumePdfStorage unsafe = new ResumePdfStorage(props);
        byte[] bytes = LocalResumePdfParserTest.textPdf(1);
        assertThrows(ServiceException.class, () -> unsafe.store(17L, bytes, "test.pdf"));
        assertEquals(0, fileCount());
    }
}
