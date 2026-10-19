package com.ruoyi.enterprise.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.domain.JdDocumentDraft;
import com.ruoyi.enterprise.service.jd.JdAiStructurer;
import com.ruoyi.system.config.JdAiProperties;
import com.ruoyi.system.config.ResumePdfProperties;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.service.app.pdf.ResumePdfParser;

/** Synthetic in-memory documents and mocked AI; no network or database writes. */
class JdDocumentServiceImplTest
{
    private static final String DOCX = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    private ResumePdfParser pdf;
    private JdAiStructurer ai;
    private DashboardMapper dashboard;
    private JdDocumentServiceImpl service;

    @BeforeEach
    void setup()
    {
        pdf = mock(ResumePdfParser.class);
        ai = mock(JdAiStructurer.class);
        dashboard = mock(DashboardMapper.class);
        service = new JdDocumentServiceImpl(pdf, new ResumePdfProperties(), new JdAiProperties(), ai, dashboard);
    }

    private MockMultipartFile pdfFile()
    {
        return new MockMultipartFile("file", "synthetic.pdf", "application/pdf", "%PDF-synthetic".getBytes(StandardCharsets.US_ASCII));
    }

    @Test
    void missingKeyStopsBeforeReadingOrParsingDocument()
    {
        doThrow(new ServiceException("后端尚未配置模型密钥")).when(ai).requireConfigured();
        assertEquals("后端尚未配置模型密钥", assertThrows(ServiceException.class,
                () -> service.parseDocument(1L, pdfFile())).getMessage());
        verifyNoInteractions(pdf);
        verify(ai, never()).structure(anyString());
    }

    @Test
    void pdfDelegatesToExistingParserAndReturnsOnlyDraft()
    {
        when(pdf.parse(any(byte[].class))).thenReturn(new ResumePdfParser.Result("Synthetic PDF job text", "TEXT"));
        JdDocumentDraft expected = new JdDocumentDraft(); expected.setTitle("Mobile Engineer");
        when(ai.structure("Synthetic PDF job text")).thenReturn(expected);
        assertSame(expected, service.parseDocument(1L, pdfFile()));
        verifyNoInteractions(dashboard);
    }

    @Test
    void ocrOutputAddsReviewWarning()
    {
        when(pdf.parse(any(byte[].class))).thenReturn(new ResumePdfParser.Result("Synthetic scanned job text", "MIXED"));
        when(ai.structure(anyString())).thenReturn(new JdDocumentDraft());
        assertTrue(service.parseDocument(1L, pdfFile()).getWarnings().stream().anyMatch(s -> s.contains("OCR")));
    }

    @Test
    void docxParagraphAndTableTextArePassedToAi() throws Exception
    {
        when(ai.structure(anyString())).thenReturn(new JdDocumentDraft());
        service.parseDocument(1L, new MockMultipartFile("file", "synthetic.docx", DOCX, wordDocument(2)));
        ArgumentCaptor<String> text = ArgumentCaptor.forClass(String.class);
        verify(ai).structure(text.capture());
        assertTrue(text.getValue().contains("Synthetic job paragraph"));
        assertTrue(text.getValue().contains("Synthetic table requirement"));
        verifyNoInteractions(pdf, dashboard);
    }

    @Test
    void missingWordPageMetadataIsExplicitlyReported() throws Exception
    {
        when(ai.structure(anyString())).thenReturn(new JdDocumentDraft());
        JdDocumentDraft draft = service.parseDocument(1L,
                new MockMultipartFile("file", "synthetic.docx", DOCX, wordDocument(0)));
        assertTrue(draft.getWarnings().stream().anyMatch(s -> s.contains("无可用页数元数据")));
    }

    @Test
    void oldDocAndDisguisedZipDoNotReachAi() throws Exception
    {
        ServiceException old = assertThrows(ServiceException.class, () -> service.parseDocument(1L,
                new MockMultipartFile("file", "legacy.doc", "application/msword", new byte[] {1})));
        assertTrue(old.getMessage().contains("旧版.doc"));
        assertThrows(ServiceException.class, () -> service.parseDocument(1L,
                new MockMultipartFile("file", "fake.docx", DOCX, "%PDF-invalid".getBytes(StandardCharsets.US_ASCII))));
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(bytes))
        {
            zip.putNextEntry(new ZipEntry("unrelated.txt")); zip.write(1); zip.closeEntry();
        }
        assertThrows(ServiceException.class, () -> service.parseDocument(1L,
                new MockMultipartFile("file", "fake.docx", DOCX, bytes.toByteArray())));
        verify(ai, never()).structure(anyString());
    }

    @Test
    void excessivePagesAndTextAreRejectedWithoutModelCall() throws Exception
    {
        assertThrows(ServiceException.class, () -> service.parseDocument(1L,
                new MockMultipartFile("file", "long.docx", DOCX, wordDocument(9))));
        when(pdf.parse(any(byte[].class))).thenReturn(new ResumePdfParser.Result("x".repeat(40001), "TEXT"));
        assertThrows(ServiceException.class, () -> service.parseDocument(1L, pdfFile()));
        verify(ai, never()).structure(anyString());
    }

    @Test
    void invalidMimeAndExcessiveBytesAreRejected()
    {
        assertThrows(ServiceException.class, () -> service.parseDocument(1L,
                new MockMultipartFile("file", "fake.pdf", "image/png", new byte[] {1})));
        MultipartFile large = mock(MultipartFile.class);
        when(large.getOriginalFilename()).thenReturn("large.pdf");
        when(large.getSize()).thenReturn(10L * 1024 * 1024 + 1);
        assertThrows(ServiceException.class, () -> service.parseDocument(1L, large));
        verify(ai, never()).structure(anyString());
    }

    @Test
    void unboundOrUnauthenticatedUserCannotParse()
    {
        assertEquals(401, assertThrows(ServiceException.class, () -> service.parseDocument(null, pdfFile())).getCode());
        when(dashboard.selectCompanyIdByUser(200L)).thenReturn(null);
        assertEquals(403, assertThrows(ServiceException.class, () -> service.parseDocument(200L, pdfFile())).getCode());
        verifyNoInteractions(ai, pdf);
    }

    private byte[] wordDocument(int pages) throws Exception
    {
        ByteArrayOutputStream word = new ByteArrayOutputStream();
        try (XWPFDocument document = new XWPFDocument())
        {
            document.createParagraph().createRun().setText("Synthetic job paragraph");
            document.createTable(1, 1).getRow(0).getCell(0).setText("Synthetic table requirement");
            document.write(word);
        }
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        try (ZipInputStream input = new ZipInputStream(new ByteArrayInputStream(word.toByteArray()));
                ZipOutputStream zip = new ZipOutputStream(output))
        {
            ZipEntry entry;
            while ((entry = input.getNextEntry()) != null)
            {
                if (!"docProps/app.xml".equals(entry.getName()))
                {
                    zip.putNextEntry(new ZipEntry(entry.getName())); input.transferTo(zip); zip.closeEntry();
                }
            }
            zip.putNextEntry(new ZipEntry("docProps/app.xml"));
            String xml = "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\"><Pages>" + pages + "</Pages></Properties>";
            zip.write(xml.getBytes(StandardCharsets.UTF_8)); zip.closeEntry();
        }
        return output.toByteArray();
    }
}
