package com.ruoyi.enterprise.service.impl;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.Semaphore;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import org.apache.poi.xwpf.extractor.XWPFWordExtractor;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.w3c.dom.NodeList;
import com.ruoyi.common.constant.ErrorCode;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.domain.JdDocumentDraft;
import com.ruoyi.enterprise.service.IJdDocumentService;
import com.ruoyi.enterprise.service.jd.JdAiStructurer;
import com.ruoyi.system.config.JdAiProperties;
import com.ruoyi.system.config.ResumePdfProperties;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.service.app.pdf.ResumePdfParser;

/** In-memory document extraction and JD drafting. No job/file persistence. */
@Service
public class JdDocumentServiceImpl implements IJdDocumentService
{
    private static final int MAX_ZIP_ENTRIES = 512;
    private static final long MAX_UNCOMPRESSED_BYTES = 20L * 1024 * 1024;
    private static final int MAX_PROPERTIES_BYTES = 64 * 1024;
    private static final String DOCX_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    private final ResumePdfParser pdfParser;
    private final ResumePdfProperties pdfProperties;
    private final JdAiProperties aiProperties;
    private final JdAiStructurer structurer;
    private final DashboardMapper dashboardMapper;
    private final Semaphore permits;

    public JdDocumentServiceImpl(ResumePdfParser pdfParser, ResumePdfProperties pdfProperties,
            JdAiProperties aiProperties, JdAiStructurer structurer, DashboardMapper dashboardMapper)
    {
        this.pdfParser = pdfParser;
        this.pdfProperties = pdfProperties;
        this.aiProperties = aiProperties;
        this.structurer = structurer;
        this.dashboardMapper = dashboardMapper;
        permits = new Semaphore(aiProperties.getMaxConcurrentRequests());
    }

    @Override
    public JdDocumentDraft parseDocument(Long userId, MultipartFile file)
    {
        requireEnterprise(userId);
        String extension = extension(file);
        long maxBytes = pdfProperties.getMaxSizeMb() * 1024L * 1024;
        if (file.getSize() > maxBytes)
        {
            throw badDocument("JD 文档不能超过" + pdfProperties.getMaxSizeMb() + "MB");
        }
        validateContentType(file.getContentType(), extension);
        // Fail before PDF/OCR/Word processing if model credentials are absent.
        structurer.requireConfigured();
        if (!permits.tryAcquire())
        {
            throw new ServiceException("JD 文档解析服务繁忙，请稍后重试");
        }
        try
        {
            byte[] bytes;
            try (InputStream input = file.getInputStream())
            {
                bytes = input.readNBytes(Math.toIntExact(maxBytes) + 1);
            }
            if (bytes.length == 0 || bytes.length > maxBytes)
            {
                throw badDocument("JD 文档为空或超过大小限制");
            }
            String text;
            List<String> warnings = new ArrayList<>();
            if ("pdf".equals(extension))
            {
                ResumePdfParser.Result parsed;
                try
                {
                    parsed = pdfParser.parse(bytes);
                }
                catch (ServiceException error)
                {
                    throw new ServiceException(error.getMessage().replace("简历", "JD"), error.getCode());
                }
                text = parsed.text();
                if (!"TEXT".equals(parsed.method()))
                {
                    warnings.add("文档含 OCR 识别结果，请特别核对薪资、数字和技能名称");
                }
            }
            else
            {
                Integer pages = validateDocxArchive(bytes);
                if (pages != null && pages > pdfProperties.getMaxPages())
                {
                    throw badDocument("DOCX 声明的页数超过" + pdfProperties.getMaxPages() + "页，请精简后重试");
                }
                warnings.add(pages == null ? "DOCX 无可用页数元数据，按文件大小和提取文本长度限制校验；如需精确页数请转为PDF"
                        : "DOCX 页数来自文档元数据，可能与实际排版不同；仅提取可编辑文字，图片和页眉页脚请人工核对");
                try (XWPFDocument document = new XWPFDocument(new ByteArrayInputStream(bytes));
                        XWPFWordExtractor extractor = new XWPFWordExtractor(document))
                {
                    text = extractor.getText();
                }
                catch (IOException | RuntimeException error)
                {
                    throw badDocument("DOCX 文档损坏、加密或格式不受支持，请转换为PDF后重试");
                }
            }
            if (text == null || text.isBlank())
            {
                throw badDocument("文档未提取到有效文字，图片型Word请转换为PDF后重试");
            }
            text = text.trim();
            if (text.length() > aiProperties.getMaxInputChars())
            {
                throw badDocument("JD 文本超过" + aiProperties.getMaxInputChars() + "个字符，请精简文档后重试");
            }
            JdDocumentDraft draft = structurer.structure(text);
            draft.getWarnings().addAll(warnings);
            return draft;
        }
        catch (ServiceException error)
        {
            throw error;
        }
        catch (IOException error)
        {
            throw badDocument("JD 文档读取失败，请重新选择文件");
        }
        finally
        {
            permits.release();
        }
    }

    private void requireEnterprise(Long userId)
    {
        if (userId == null)
        {
            throw new ServiceException("请先登录企业端", ErrorCode.UNAUTHORIZED);
        }
        if (!SecurityUtils.isAdmin(userId) && dashboardMapper.selectCompanyIdByUser(userId) == null)
        {
            throw new ServiceException("请先完成企业绑定并通过审核，再解析JD文档", ErrorCode.FORBIDDEN);
        }
    }

    private String extension(MultipartFile file)
    {
        if (file == null || file.isEmpty()) throw badDocument("请选择一个PDF或DOCX文档");
        String name = file.getOriginalFilename();
        if (name == null) throw badDocument("文档缺少文件名");
        name = name.toLowerCase(Locale.ROOT);
        if (name.endsWith(".doc")) throw badDocument("暂不支持旧版.doc，请转换为PDF或DOCX后上传");
        if (name.endsWith(".pdf")) return "pdf";
        if (name.endsWith(".docx")) return "docx";
        throw badDocument("仅支持PDF或DOCX文档");
    }

    private void validateContentType(String contentType, String extension)
    {
        if (contentType == null || contentType.isBlank() || "application/octet-stream".equalsIgnoreCase(contentType)) return;
        String expected = "pdf".equals(extension) ? "application/pdf" : DOCX_TYPE;
        if (!expected.equalsIgnoreCase(contentType)) throw badDocument("文档类型与扩展名不匹配");
    }

    private Integer validateDocxArchive(byte[] bytes) throws IOException
    {
        if (bytes.length < 4 || bytes[0] != 'P' || bytes[1] != 'K' || bytes[2] != 3 || bytes[3] != 4)
        {
            throw badDocument("DOCX 文件头校验失败，请转换为PDF后重试");
        }
        Set<String> names = new HashSet<>();
        byte[] propertiesXml = null;
        long total = 0;
        try (ZipInputStream input = new ZipInputStream(new ByteArrayInputStream(bytes)))
        {
            ZipEntry entry;
            byte[] buffer = new byte[8192];
            while ((entry = input.getNextEntry()) != null)
            {
                if (!names.add(entry.getName()) || names.size() > MAX_ZIP_ENTRIES)
                {
                    throw badDocument("DOCX 压缩内容异常或过多，请精简后重试");
                }
                if (entry.getName().toLowerCase(Locale.ROOT).endsWith("vbaproject.bin"))
                {
                    throw badDocument("不支持包含宏的Word文档，请转换为PDF后重试");
                }
                boolean properties = "docProps/app.xml".equals(entry.getName());
                ByteArrayOutputStream metadata = properties ? new ByteArrayOutputStream() : null;
                int read;
                while ((read = input.read(buffer)) != -1)
                {
                    total += read;
                    if (total > MAX_UNCOMPRESSED_BYTES) throw badDocument("DOCX 解压内容超过20MB，请精简后重试");
                    if (properties)
                    {
                        if (metadata.size() + read > MAX_PROPERTIES_BYTES) throw badDocument("DOCX 页数元数据异常");
                        metadata.write(buffer, 0, read);
                    }
                }
                if (properties) propertiesXml = metadata.toByteArray();
                input.closeEntry();
            }
        }
        if (!names.contains("[Content_Types].xml") || !names.contains("word/document.xml"))
        {
            throw badDocument("文件不是有效的DOCX文档");
        }
        return propertiesXml == null ? null : declaredPages(propertiesXml);
    }

    private Integer declaredPages(byte[] xml)
    {
        try
        {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setNamespaceAware(true);
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
            factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
            NodeList nodes = factory.newDocumentBuilder().parse(new ByteArrayInputStream(xml))
                    .getElementsByTagNameNS("*", "Pages");
            if (nodes.getLength() == 0) return null;
            int pages = Integer.parseInt(nodes.item(0).getTextContent().trim());
            return pages <= 0 ? null : pages;
        }
        catch (Exception error)
        {
            throw badDocument("DOCX 页数元数据无法读取，请转换为PDF后重试");
        }
    }

    private ServiceException badDocument(String message)
    {
        return new ServiceException(message, ErrorCode.BAD_REQUEST);
    }
}
