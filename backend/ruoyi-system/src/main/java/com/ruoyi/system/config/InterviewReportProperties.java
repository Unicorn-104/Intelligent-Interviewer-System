package com.ruoyi.system.config;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 面试报告自动生成的运行参数。
 *
 * 模型地址、密钥与模型名来自数据库 t_model_provider，由 AgentModelClient 统一读取；
 * 关闭 enabled 可快速回滚到「不生成报告」的旧行为。
 */
@Configuration
@ConfigurationProperties(prefix = "app.report")
public class InterviewReportProperties
{
    /** 总开关：关闭后不生成，状态保持未触发 */
    private boolean enabled = true;

    /** 单段送入模型的最大字符数，超出按题目边界分段 */
    @Min(500) @Max(20000) private int maxCharsPerChunk = 4000;

    /** 同时调用模型的最大场次数 */
    @Min(1) @Max(4) private int maxConcurrentRequests = 2;

    /** 单次模型调用超时（秒） */
    @Min(10) @Max(180) private int callTimeoutSeconds = 85;

    /** 单次模型调用最大输出 token */
    @Min(500) @Max(8000) private int maxTokens = 4000;

    /** 有效逐字稿最少字符数，低于此值判定为数据不足 */
    @Min(50) @Max(2000) private int minTranscriptChars = 200;

    /** 最少完成题目数，低于此值判定为数据不足 */
    @Min(0) @Max(20) private int minAnswered = 2;

    /** 允许的最大重试次数（自动补偿 + HR 手动） */
    @Min(0) @Max(10) private int maxRetry = 3;

    /** 生成中超时后允许重新抢占的分钟数 */
    @Min(1) @Max(60) private int retryWindowMinutes = 10;

    /** 补偿任务回溯的天数 */
    @Min(1) @Max(30) private int scanDays = 7;

    public boolean isEnabled()
    {
        return enabled;
    }

    public void setEnabled(boolean enabled)
    {
        this.enabled = enabled;
    }

    public int getMaxCharsPerChunk()
    {
        return maxCharsPerChunk;
    }

    public void setMaxCharsPerChunk(int maxCharsPerChunk)
    {
        this.maxCharsPerChunk = maxCharsPerChunk;
    }

    public int getMaxConcurrentRequests()
    {
        return maxConcurrentRequests;
    }

    public void setMaxConcurrentRequests(int maxConcurrentRequests)
    {
        this.maxConcurrentRequests = maxConcurrentRequests;
    }

    public int getCallTimeoutSeconds()
    {
        return callTimeoutSeconds;
    }

    public void setCallTimeoutSeconds(int callTimeoutSeconds)
    {
        this.callTimeoutSeconds = callTimeoutSeconds;
    }

    public int getMaxTokens()
    {
        return maxTokens;
    }

    public void setMaxTokens(int maxTokens)
    {
        this.maxTokens = maxTokens;
    }

    public int getMinTranscriptChars()
    {
        return minTranscriptChars;
    }

    public void setMinTranscriptChars(int minTranscriptChars)
    {
        this.minTranscriptChars = minTranscriptChars;
    }

    public int getMinAnswered()
    {
        return minAnswered;
    }

    public void setMinAnswered(int minAnswered)
    {
        this.minAnswered = minAnswered;
    }

    public int getMaxRetry()
    {
        return maxRetry;
    }

    public void setMaxRetry(int maxRetry)
    {
        this.maxRetry = maxRetry;
    }

    public int getRetryWindowMinutes()
    {
        return retryWindowMinutes;
    }

    public void setRetryWindowMinutes(int retryWindowMinutes)
    {
        this.retryWindowMinutes = retryWindowMinutes;
    }

    public int getScanDays()
    {
        return scanDays;
    }

    public void setScanDays(int scanDays)
    {
        this.scanDays = scanDays;
    }
}
