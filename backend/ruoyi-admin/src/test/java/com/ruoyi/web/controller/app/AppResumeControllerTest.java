package com.ruoyi.web.controller.app;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.ArgumentCaptor;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.system.config.ResumePdfProperties;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.domain.app.AppResumePdfDocument;
import com.ruoyi.system.service.app.IAppResumeService;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class AppResumeControllerTest
{
    @TempDir Path directory;
    private MockMvc mvc;
    private IAppResumeService service;

    @BeforeEach
    void setup()
    {
        service = mock(IAppResumeService.class);
        AppResumeController controller = new AppResumeController();
        ReflectionTestUtils.setField(controller, "resumeService", service);
        ReflectionTestUtils.setField(controller, "pdfProperties", new ResumePdfProperties());
        mvc = MockMvcBuilders.standaloneSetup(controller).build();
        LoginUser user = new LoginUser(17L, 1L, new SysUser(), Set.of());
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(user, null, Set.of()));
    }

    @AfterEach
    void clearLogin() { SecurityContextHolder.clearContext(); }

    @Test
    void bindsJsonPartAndDoesNotExposeOrAcceptServerFilePaths() throws Exception
    {
        AppResume saved = new AppResume();
        saved.setResumeId(7L);
        saved.setResumeName("已核对的简历");
        saved.setFilePath("private-resume/17/2026/10/13/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf");
        saved.setFileName("简历.pdf");
        saved.setFileSize(14L);
        when(service.saveResumeWithPdf(eq(17L), any(AppResume.class), any(byte[].class), eq("简历.pdf"))).thenReturn(saved);
        String json = """
            {"resumeName":"已核对的简历","jobDirection":"Java 开发", "filePath":"../../outside.pdf", "fileName":"forged.pdf"}
            """;
        byte[] pdf = "%PDF-test-data".getBytes(StandardCharsets.UTF_8);
        mvc.perform(multipart("/app/resumes/import-pdf")
                        .file(new MockMultipartFile("resume", "resume.json", MediaType.APPLICATION_JSON_VALUE, json.getBytes(StandardCharsets.UTF_8)))
                        .file(new MockMultipartFile("file", "简历.pdf", MediaType.APPLICATION_PDF_VALUE, pdf)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.fileName").value("简历.pdf"))
                .andExpect(jsonPath("$.data.pdfUrl").value("/app/resumes/7/pdf"))
                .andExpect(jsonPath("$.data.filePath").doesNotExist());
        ArgumentCaptor<AppResume> draft = ArgumentCaptor.forClass(AppResume.class);
        ArgumentCaptor<byte[]> bytes = ArgumentCaptor.forClass(byte[].class);
        verify(service).saveResumeWithPdf(eq(17L), draft.capture(), bytes.capture(), eq("简历.pdf"));
        assertEquals("Java 开发", draft.getValue().getJobDirection());
        assertNull(draft.getValue().getFilePath());
        assertNull(draft.getValue().getFileName());
        assertArrayEquals(pdf, bytes.getValue());
    }

    @Test
    void authorizedPdfResponseKeepsOriginalBytesAndDisablesCaching() throws Exception
    {
        byte[] bytes = "%PDF-synthetic".getBytes(StandardCharsets.UTF_8);
        Path file = directory.resolve("fixture.pdf");
        Files.write(file, bytes);
        when(service.selectPdf(17L, 7L)).thenReturn(new AppResumePdfDocument(file, "简历.pdf"));
        mvc.perform(get("/app/resumes/7/pdf"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_PDF))
                .andExpect(content().bytes(bytes))
                .andExpect(header().string("Cache-Control", "private, no-store"))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"));
        verify(service).selectPdf(17L, 7L);
    }
}
