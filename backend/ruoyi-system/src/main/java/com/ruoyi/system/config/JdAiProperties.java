package com.ruoyi.system.config;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.validation.annotation.Validated;

/** JD-only configuration; credentials are supplied by private configuration or environment. */
@Configuration
@ConfigurationProperties(prefix = "app.jd.ai")
@Validated
public class JdAiProperties
{
    private boolean enabled = true;
    @NotBlank private String baseUrl = "https://api.deepseek.com/anthropic";
    @NotBlank private String model = "deepseek-v4-pro";
    private String apiKey = "";
    @Min(5) @Max(120) private int timeoutSeconds = 60;
    @Min(1000) @Max(100000) private int maxInputChars = 40000;
    @Min(1) @Max(4) private int maxConcurrentRequests = 2;

    public boolean isEnabled() { return enabled; }
    public void setEnabled(boolean value) { enabled = value; }
    public String getBaseUrl() { return baseUrl; }
    public void setBaseUrl(String value) { baseUrl = value; }
    public String getModel() { return model; }
    public void setModel(String value) { model = value; }
    public String getApiKey() { return apiKey; }
    public void setApiKey(String value) { apiKey = value; }
    public int getTimeoutSeconds() { return timeoutSeconds; }
    public void setTimeoutSeconds(int value) { timeoutSeconds = value; }
    public int getMaxInputChars() { return maxInputChars; }
    public void setMaxInputChars(int value) { maxInputChars = value; }
    public int getMaxConcurrentRequests() { return maxConcurrentRequests; }
    public void setMaxConcurrentRequests(int value) { maxConcurrentRequests = value; }
}
