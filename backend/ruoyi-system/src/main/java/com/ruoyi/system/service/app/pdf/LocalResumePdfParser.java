package com.ruoyi.system.service.app.pdf;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.concurrent.Semaphore;
import java.util.stream.Stream;
import jakarta.annotation.PreDestroy;
import net.sourceforge.tess4j.ITesseract;
import net.sourceforge.tess4j.Tesseract;
import net.sourceforge.tess4j.TesseractException;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.rendering.ImageType;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.ResumePdfProperties;

/** 逐页提取文字，避免混合 PDF 中的扫描页被整份文本层判断跳过。 */
@Component
public class LocalResumePdfParser implements ResumePdfParser
{
    private final ResumePdfProperties properties;
    private final Semaphore permits;
    private Path modelDirectory;

    public LocalResumePdfParser(ResumePdfProperties properties)
    {
        this.properties = properties;
        permits = new Semaphore(properties.getMaxConcurrentParses());
    }

    @Override
    public Result parse(byte[] bytes)
    {
        checkSize(bytes);
        if (!permits.tryAcquire()) throw new ServiceException("简历识别服务繁忙，请稍后重试");
        try (PDDocument document = Loader.loadPDF(bytes))
        {
            checkDocument(document);
            PDFTextStripper stripper = new PDFTextStripper();
            stripper.setSortByPosition(true);
            PDFRenderer renderer = new PDFRenderer(document);
            StringBuilder result = new StringBuilder();
            ITesseract ocr = null;
            int ocrPages = 0;
            for (int page = 0; page < document.getNumberOfPages(); page++)
            {
                stripper.setStartPage(page + 1);
                stripper.setEndPage(page + 1);
                String text = stripper.getText(document);
                boolean useOcr = properties.getParser() == ResumePdfProperties.Parser.OCR
                        || (properties.getParser() == ResumePdfProperties.Parser.AUTO
                        && text.replaceAll("\\s", "").length() < properties.getMinTextChars());
                if (useOcr)
                {
                    if (ocr == null)
                    {
                        try { ocr = createOcr(); }
                        catch (IOException error) { throw new ServiceException("OCR 语言模型加载失败，请检查模型配置"); }
                    }
                    checkImageSize(document.getPage(page));
                    BufferedImage image = renderer.renderImageWithDPI(page, properties.getDpi(), ImageType.GRAY);
                    try { text = ocr.doOCR(image); }
                    finally { image.flush(); }
                    ocrPages++;
                }
                result.append(text).append('\n');
            }
            String text = result.toString().trim();
            if (text.replaceAll("\\s", "").length() < 20)
            {
                throw new ServiceException(properties.getParser() == ResumePdfProperties.Parser.TEXT
                        ? "PDF 没有足够的文本层，请配置 AUTO 或 OCR 模式后重试"
                        : "未识别到有效简历内容，请上传清晰、方向正确的 PDF");
            }
            return new Result(text, ocrPages == 0 ? "TEXT"
                    : ocrPages == document.getNumberOfPages() ? "OCR" : "MIXED");
        }
        catch (ServiceException error) { throw error; }
        catch (TesseractException | LinkageError error)
        {
            throw new ServiceException("OCR 识别失败，请检查模型及本机 OCR 运行环境");
        }
        catch (Error error)
        {
            // JNA throws the base Error for native access violations; do not swallow VM failures.
            if (error.getClass() == Error.class && "Invalid memory access".equals(error.getMessage()))
                throw new ServiceException("OCR 引擎初始化失败，请检查本机 OCR 运行环境后重试");
            throw error;
        }
        catch (IOException error) { throw new ServiceException("PDF 文件损坏、加密或无法读取"); }
        finally { permits.release(); }
    }

    @Override
    public void validate(byte[] bytes)
    {
        checkSize(bytes);
        try (PDDocument document = Loader.loadPDF(bytes)) { checkDocument(document); }
        catch (IOException error) { throw new ServiceException("PDF 文件损坏、加密或无法读取"); }
    }

    private void checkSize(byte[] bytes)
    {
        if (bytes == null || bytes.length == 0) throw new ServiceException("请选择 PDF 文件");
        if (bytes.length > properties.getMaxSizeMb() * 1024L * 1024)
            throw new ServiceException("PDF 不能超过 " + properties.getMaxSizeMb() + "MB");
        if (bytes.length < 5 || bytes[0] != '%' || bytes[1] != 'P' || bytes[2] != 'D'
                || bytes[3] != 'F' || bytes[4] != '-') throw new ServiceException("PDF 文件头校验失败");
    }

    private void checkDocument(PDDocument document)
    {
        if (document.isEncrypted()) throw new ServiceException("暂不支持加密 PDF，请先解除加密");
        if (document.getNumberOfPages() < 1 || document.getNumberOfPages() > properties.getMaxPages())
            throw new ServiceException("PDF 页数需为 1-" + properties.getMaxPages() + " 页");
    }

    private void checkImageSize(PDPage page)
    {
        double scale = properties.getDpi() / 72.0 * page.getUserUnit();
        double pixels = page.getCropBox().getWidth() * scale * page.getCropBox().getHeight() * scale;
        if (!Double.isFinite(pixels) || pixels <= 0 || pixels > 16_000_000)
            throw new ServiceException("PDF 页面尺寸过大，请使用标准 A4 页面后重试");
    }

    protected ITesseract createOcr() throws IOException
    {
        ITesseract ocr = new Tesseract();
        ocr.setDatapath(models().toString());
        ocr.setLanguage(properties.getLanguage());
        ocr.setPageSegMode(properties.getPageSegMode());
        ocr.setVariable("user_defined_dpi", String.valueOf(properties.getDpi()));
        return ocr;
    }

    private synchronized Path models() throws IOException
    {
        if (!properties.getTessdataDirectory().isBlank())
        {
            Path external = Path.of(properties.getTessdataDirectory()).toAbsolutePath().normalize();
            for (String language : properties.getLanguage().split("\\+"))
                if (!language.matches("[a-zA-Z0-9_]+") || !Files.isRegularFile(external.resolve(language + ".traineddata")))
                    throw new ServiceException("OCR 语言模型缺失，请检查 tessdata-directory 配置");
            return external;
        }
        if (modelDirectory != null) return modelDirectory;
        Path directory = Files.createTempDirectory("resume-ocr-models-");
        try
        {
            for (String language : properties.getLanguage().split("\\+"))
            {
                if (!language.matches("[a-zA-Z0-9_]+")) throw new ServiceException("OCR 语言配置无效");
                String name = language + ".traineddata";
                try (InputStream input = new ClassPathResource("tessdata/" + name).getInputStream())
                {
                    Files.copy(input, directory.resolve(name));
                }
            }
            modelDirectory = directory;
            return directory;
        }
        catch (IOException | RuntimeException error)
        {
            deleteDirectory(directory);
            throw error;
        }
    }

    @PreDestroy
    public synchronized void close()
    {
        if (modelDirectory != null) deleteDirectory(modelDirectory);
        modelDirectory = null;
    }

    private void deleteDirectory(Path directory)
    {
        try (Stream<Path> paths = Files.walk(directory))
        {
            paths.sorted(Comparator.reverseOrder()).forEach(path -> {
                try { Files.deleteIfExists(path); } catch (IOException ignored) { }
            });
        }
        catch (IOException ignored) { }
    }
}
