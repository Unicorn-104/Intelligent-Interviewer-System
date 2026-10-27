package com.ruoyi.system.config;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.validation.annotation.Validated;

/** OCR 文本的 AI 字段编排；环境变量或私有配置优先，后台启用的模型 Provider 可作为兜底。 */
@Configuration
@PropertySource("classpath:resume-pdf.properties")
@ConfigurationProperties(prefix = "app.resume.structure")
@Validated
public class ResumeStructureProperties
{
    private boolean enabled = true;
    @NotBlank private String apiUrl = "https://api.deepseek.com/chat/completions";
    @NotBlank private String model = "deepseek-chat";
    private String apiKey = "";
    @Min(5) @Max(90) private int timeoutSeconds = 60;
    @Min(1024) @Max(8192) private int maxTokens = 8192;
    @Min(1000) @Max(100000) private int maxInputChars = 40000;
    @Min(1) @Max(4) private int maxConcurrentRequests = 2;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean value) { enabled = value; }
    public String getApiUrl() { return apiUrl; }
    public void setApiUrl(String value) { apiUrl = value; }
    public String getModel() { return model; }
    public void setModel(String value) { model = value; }
    public String getApiKey() { return apiKey; }
    public void setApiKey(String value) { apiKey = value; }
    public int getTimeoutSeconds() { return timeoutSeconds; }
    public void setTimeoutSeconds(int value) { timeoutSeconds = value; }
    public int getMaxTokens() { return maxTokens; }
    public void setMaxTokens(int value) { maxTokens = value; }
    public int getMaxInputChars() { return maxInputChars; }
    public void setMaxInputChars(int value) { maxInputChars = value; }
    public int getMaxConcurrentRequests() { return maxConcurrentRequests; }
    public void setMaxConcurrentRequests(int value) { maxConcurrentRequests = value; }
}
