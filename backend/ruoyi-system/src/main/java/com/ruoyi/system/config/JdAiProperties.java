package com.ruoyi.system.config;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 企业端 AI（JD 文档解析 / AI 筛选）的运行限制配置。
 *
 * 模型地址、密钥与模型名已迁移至数据库 t_model_provider（管理员维护），
 * 由 AgentModelClient 统一读取；本类仅保留输入长度与并发限制等本地运行参数。
 */
@Configuration
@ConfigurationProperties(prefix = "jd.ai")
public class JdAiProperties
{
    @Min(1000) @Max(100000) private int maxInputChars = 40000;

    @Min(1) @Max(4) private int maxConcurrentRequests = 2;

    public int getMaxInputChars()
    {
        return maxInputChars;
    }

    public void setMaxInputChars(int maxInputChars)
    {
        this.maxInputChars = maxInputChars;
    }

    public int getMaxConcurrentRequests()
    {
        return maxConcurrentRequests;
    }

    public void setMaxConcurrentRequests(int maxConcurrentRequests)
    {
        this.maxConcurrentRequests = maxConcurrentRequests;
    }
}
