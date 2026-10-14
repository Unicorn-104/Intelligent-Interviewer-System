package com.ruoyi.system.service.app.pdf;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import net.sourceforge.tess4j.ITesseract;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.encryption.AccessPermission;
import org.apache.pdfbox.pdmodel.encryption.StandardProtectionPolicy;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.apache.pdfbox.pdmodel.graphics.image.LosslessFactory;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.junit.jupiter.api.Test;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.ResumePdfProperties;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class LocalResumePdfParserTest
{
    private static final String TEXT = "Java Developer Resume: education, software engineering, project experience, programming skills and backend development.";

    static byte[] textPdf(int pages) throws Exception
    {
        try (PDDocument document = new PDDocument(); ByteArrayOutputStream output = new ByteArrayOutputStream())
        {
            for (int page = 0; page < pages; page++) addTextPage(document);
            document.save(output);
            return output.toByteArray();
        }
    }

    private static void addTextPage(PDDocument document) throws Exception
    {
        PDPage page = new PDPage(PDRectangle.A4);
        document.addPage(page);
        try (PDPageContentStream content = new PDPageContentStream(document, page))
        {
            content.beginText();
            content.setFont(new PDType1Font(Standard14Fonts.FontName.HELVETICA), 14);
            content.newLineAtOffset(35, 780);
            content.showText(TEXT.substring(0, 62));
            content.newLineAtOffset(0, -30);
            content.showText(TEXT.substring(62));
            content.endText();
        }
    }

    static byte[] scannedPdf(boolean includeTextPage) throws Exception
    {
        try (PDDocument source = new PDDocument(); PDDocument document = new PDDocument();
             ByteArrayOutputStream output = new ByteArrayOutputStream())
        {
            addTextPage(source);
            BufferedImage image = new PDFRenderer(source).renderImageWithDPI(0, 150);
            if (includeTextPage) addTextPage(document);
            PDPage page = new PDPage(PDRectangle.A4);
            document.addPage(page);
            try (PDPageContentStream content = new PDPageContentStream(document, page))
            {
                content.drawImage(LosslessFactory.createFromImage(document, image), 0, 0,
                        PDRectangle.A4.getWidth(), PDRectangle.A4.getHeight());
            }
            image.flush();
            document.save(output);
            return output.toByteArray();
        }
    }

    @Test
    void textLayerDoesNotRequireOcrModels() throws Exception
    {
        ResumePdfProperties props = new ResumePdfProperties();
        props.setTessdataDirectory("nonexistent-model-directory");
        LocalResumePdfParser.Result result = new LocalResumePdfParser(props).parse(textPdf(1));
        assertEquals("TEXT", result.method());
        assertTrue(result.text().contains("Java Developer"));
    }

    @Test
    void mixedPdfRecognizesOnlyTheScannedPage() throws Exception
    {
        ITesseract ocr = mock(ITesseract.class);
        when(ocr.doOCR(any(BufferedImage.class))).thenReturn("Scanned page contains additional project experience");
        LocalResumePdfParser parser = new LocalResumePdfParser(new ResumePdfProperties())
        {
            @Override protected ITesseract createOcr() { return ocr; }
        };
        ResumePdfParser.Result result = parser.parse(scannedPdf(true));
        assertEquals("MIXED", result.method());
        assertTrue(result.text().contains("additional project"));
        verify(ocr, times(1)).doOCR(any(BufferedImage.class));
    }

    @Test
    void forcedOcrRecognizesEvenTextPages() throws Exception
    {
        ResumePdfProperties props = new ResumePdfProperties();
        props.setParser(ResumePdfProperties.Parser.OCR);
        ITesseract ocr = mock(ITesseract.class);
        when(ocr.doOCR(any(BufferedImage.class))).thenReturn(TEXT);
        LocalResumePdfParser parser = new LocalResumePdfParser(props)
        {
            @Override protected ITesseract createOcr() { return ocr; }
        };
        assertEquals("OCR", parser.parse(textPdf(1)).method());
        verify(ocr).doOCR(any(BufferedImage.class));
    }

    @Test
    void textOnlyModeExplainsScannedPdfFailure() throws Exception
    {
        ResumePdfProperties props = new ResumePdfProperties();
        props.setParser(ResumePdfProperties.Parser.TEXT);
        byte[] pdf = scannedPdf(false);
        assertTrue(assertThrows(ServiceException.class, () -> new LocalResumePdfParser(props).parse(pdf))
                .getMessage().contains("AUTO 或 OCR"));
    }

    @Test
    void rejectsFakeHeaderCorruptionAndTooManyPages() throws Exception
    {
        LocalResumePdfParser parser = new LocalResumePdfParser(new ResumePdfProperties());
        assertThrows(ServiceException.class, () -> parser.validate("not pdf".getBytes()));
        assertThrows(ServiceException.class, () -> parser.validate("%PDF-broken".getBytes()));
        byte[] ninePages = textPdf(9);
        assertThrows(ServiceException.class, () -> parser.validate(ninePages));
        parser.validate(textPdf(8));
    }

    @Test
    void rejectsEncryptedPdf() throws Exception
    {
        byte[] bytes;
        try (PDDocument document = new PDDocument(); ByteArrayOutputStream output = new ByteArrayOutputStream())
        {
            addTextPage(document);
            document.protect(new StandardProtectionPolicy("owner", "", new AccessPermission()));
            document.save(output);
            bytes = output.toByteArray();
        }
        LocalResumePdfParser parser = new LocalResumePdfParser(new ResumePdfProperties());
        assertThrows(ServiceException.class, () -> parser.validate(bytes));
    }

    @Test
    void nativeAccessErrorBecomesSafeBusinessErrorAndReleasesCapacity() throws Exception
    {
        ResumePdfProperties props = new ResumePdfProperties();
        props.setMaxConcurrentParses(1);
        props.setParser(ResumePdfProperties.Parser.OCR);
        ITesseract ocr = mock(ITesseract.class);
        when(ocr.doOCR(any(BufferedImage.class))).thenThrow(new Error("Invalid memory access"))
                .thenReturn(TEXT);
        LocalResumePdfParser parser = new LocalResumePdfParser(props)
        {
            @Override protected ITesseract createOcr() { return ocr; }
        };
        byte[] bytes = textPdf(1);
        ServiceException error = assertThrows(ServiceException.class, () -> parser.parse(bytes));
        assertTrue(error.getMessage().contains("OCR 引擎初始化失败"));
        assertFalse(error.getMessage().contains("java.lang.Error"));
        assertEquals("OCR", parser.parse(bytes).method());
    }

    @Test
    void vmFailuresAreNotConvertedToRecognitionErrors() throws Exception
    {
        ResumePdfProperties props = new ResumePdfProperties();
        props.setParser(ResumePdfProperties.Parser.OCR);
        ITesseract ocr = mock(ITesseract.class);
        when(ocr.doOCR(any(BufferedImage.class))).thenThrow(new OutOfMemoryError("synthetic failure"));
        LocalResumePdfParser parser = new LocalResumePdfParser(props)
        {
            @Override protected ITesseract createOcr() { return ocr; }
        };
        byte[] bytes = textPdf(1);
        assertThrows(OutOfMemoryError.class, () -> parser.parse(bytes));
    }

    @Test
    void realPackagedOcrReadsSyntheticScan() throws Exception
    {
        LocalResumePdfParser parser = new LocalResumePdfParser(new ResumePdfProperties());
        try
        {
            ResumePdfParser.Result result = parser.parse(scannedPdf(false));
            assertEquals("OCR", result.method());
            assertTrue(result.text().toLowerCase().contains("java"), "Synthetic OCR did not recognize Java");
            java.nio.file.Path target = java.nio.file.Path.of("target", "resume-pdf-samples");
            java.nio.file.Files.createDirectories(target);
            java.nio.file.Files.write(target.resolve("synthetic-scan.pdf"), scannedPdf(false));
            java.nio.file.Files.write(target.resolve("synthetic-text.pdf"), textPdf(1));
        }
        finally { parser.close(); }
    }
}
