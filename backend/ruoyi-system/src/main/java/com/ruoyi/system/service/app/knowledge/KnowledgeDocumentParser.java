package com.ruoyi.system.service.app.knowledge;

import java.io.ByteArrayInputStream;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.text.PDFTextStripper;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.springframework.stereotype.Component;

/** Bounded extraction with stable page/paragraph locations; no OCR or external requests. */
@Component
public class KnowledgeDocumentParser
{
    public record Part(Integer page, String section, String text) { }
    public static final int MAX_BYTES = 20 * 1024 * 1024;
    private static final int MAX_CHARS = 200000;

    public List<Part> parse(byte[] bytes, String extension) throws Exception
    {
        if (bytes.length == 0 || bytes.length > MAX_BYTES) throw new IllegalArgumentException("FILE_SIZE");
        List<Part> parts = new ArrayList<>();
        int total = 0;
        switch (extension)
        {
            case "pdf" -> {
                if (bytes.length < 5 || !new String(bytes, 0, 5, StandardCharsets.US_ASCII).equals("%PDF-"))
                    throw new IllegalArgumentException("FILE_FORMAT");
                try (var doc = Loader.loadPDF(bytes))
                {
                    if (doc.isEncrypted() || doc.getNumberOfPages() > 100) throw new IllegalArgumentException("PDF_LIMIT");
                    var stripper = new PDFTextStripper();
                    for (int page = 1; page <= doc.getNumberOfPages(); page++)
                    {
                        stripper.setStartPage(page); stripper.setEndPage(page);
                        String text = stripper.getText(doc);
                        total = bounded(total, text);
                        parts.add(new Part(page, "第 " + page + " 页", text));
                    }
                }
            }
            case "docx" -> {
                try (var doc = new XWPFDocument(new ByteArrayInputStream(bytes)))
                {
                    int paragraph = 0;
                    for (var element : doc.getBodyElements())
                    {
                        String text = element instanceof org.apache.poi.xwpf.usermodel.XWPFParagraph p ? p.getText()
                                : element instanceof org.apache.poi.xwpf.usermodel.XWPFTable t ? t.getText() : "";
                        total = bounded(total, text);
                        parts.add(new Part(null, "段落 " + (++paragraph), text));
                    }
                }
            }
            case "txt", "md" -> {
                String text = StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                        .decode(ByteBuffer.wrap(bytes)).toString();
                bounded(0, text);
                String section = "正文";
                for (String paragraph : text.split("\n\s*\n"))
                {
                    String first = paragraph.lines().findFirst().orElse("");
                    if (extension.equals("md") && first.startsWith("#"))
                        section = first.replaceFirst("^#+\s*", "").strip();
                    parts.add(new Part(null, section.substring(0, Math.min(180, section.length())), paragraph));
                }
            }
            default -> throw new IllegalArgumentException("FILE_FORMAT");
        }
        var chunks = new ArrayList<Part>();
        for (Part part : parts)
        {
            String text = part.text().replace(String.valueOf((char) 0), "").strip();
            // <=120 Unicode codepoints bounds even a UTF-8 byte tokenizer to <=480 tokens (plus query prefix).
            int[] points = text.codePoints().toArray();
            for (int start = 0; start < points.length; start += 100)
            {
                chunks.add(new Part(part.page(), part.section(), new String(points, start, Math.min(120, points.length - start))));
                if (start + 120 >= points.length) break;
            }
        }
        if (chunks.isEmpty()) throw new IllegalArgumentException("NO_TEXT_OCR_REQUIRED");
        if (chunks.size() > 2500) throw new IllegalArgumentException("TEXT_LIMIT");
        return chunks;
    }

    private int bounded(int total, String text)
    {
        if (total + text.length() > MAX_CHARS) throw new IllegalArgumentException("TEXT_LIMIT");
        return total + text.length();
    }
}
