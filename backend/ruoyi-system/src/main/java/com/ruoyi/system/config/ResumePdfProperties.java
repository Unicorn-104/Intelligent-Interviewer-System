package com.ruoyi.system.config;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.validation.annotation.Validated;

/** 简历 PDF 的解析与私有文件存储配置。 */
@Configuration
@PropertySource("classpath:resume-pdf.properties")
@ConfigurationProperties(prefix = "app.resume.pdf")
@Validated
public class ResumePdfProperties
{
    public enum Parser { AUTO, OCR, TEXT }

    @NotNull private Parser parser = Parser.AUTO;
    @Min(1) @Max(10) private int maxSizeMb = 10;
    @Min(1) @Max(8) private int maxPages = 8;
    @Min(100) @Max(300) private int dpi = 220;
    @Min(0) @Max(13) private int pageSegMode = 3;
    @Min(1) @Max(1000) private int minTextChars = 80;
    @Min(1) @Max(4) private int maxConcurrentParses = 2;
    @NotBlank private String language = "chi_sim+eng";
    private String tessdataDirectory = "";
    private String storageDirectory = "";

    public Parser getParser() { return parser; }
    public void setParser(Parser parser) { this.parser = parser; }
    public int getMaxSizeMb() { return maxSizeMb; }
    public void setMaxSizeMb(int value) { maxSizeMb = value; }
    public int getMaxPages() { return maxPages; }
    public void setMaxPages(int value) { maxPages = value; }
    public int getDpi() { return dpi; }
    public void setDpi(int value) { dpi = value; }
    public int getPageSegMode() { return pageSegMode; }
    public void setPageSegMode(int value) { pageSegMode = value; }
    public int getMinTextChars() { return minTextChars; }
    public void setMinTextChars(int value) { minTextChars = value; }
    public int getMaxConcurrentParses() { return maxConcurrentParses; }
    public void setMaxConcurrentParses(int value) { maxConcurrentParses = value; }
    public String getLanguage() { return language; }
    public void setLanguage(String value) { language = value; }
    public String getTessdataDirectory() { return tessdataDirectory; }
    public void setTessdataDirectory(String value) { tessdataDirectory = value; }
    public String getStorageDirectory() { return storageDirectory; }
    public void setStorageDirectory(String value) { storageDirectory = value; }
}
