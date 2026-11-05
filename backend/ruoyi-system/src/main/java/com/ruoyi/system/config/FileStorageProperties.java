package com.ruoyi.system.config;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.validation.annotation.Validated;

/** 原文件存储配置；S3 地址仅供后端访问，不返回客户端。 */
@Configuration
@PropertySource("classpath:file-storage.properties")
@ConfigurationProperties(prefix = "app.storage")
@Validated
public class FileStorageProperties
{
    public enum Provider { LOCAL, S3 }

    @NotNull private Provider provider = Provider.LOCAL;
    @Valid @NotNull private S3 s3 = new S3();

    public Provider getProvider() { return provider; }
    public void setProvider(Provider provider) { this.provider = provider; }
    public S3 getS3() { return s3; }
    public void setS3(S3 s3) { this.s3 = s3; }

    public static class S3
    {
        private String endpoint = "";
        private String region = "us-east-1";
        private String bucket = "recruit-files";
        private String accessKey = "";
        private String secretKey = "";
        private boolean pathStyle = true;
        @Min(1) @Max(300) private int timeoutSeconds = 60;

        public String getEndpoint() { return endpoint; }
        public void setEndpoint(String endpoint) { this.endpoint = endpoint; }
        public String getRegion() { return region; }
        public void setRegion(String region) { this.region = region; }
        public String getBucket() { return bucket; }
        public void setBucket(String bucket) { this.bucket = bucket; }
        public String getAccessKey() { return accessKey; }
        public void setAccessKey(String accessKey) { this.accessKey = accessKey; }
        public String getSecretKey() { return secretKey; }
        public void setSecretKey(String secretKey) { this.secretKey = secretKey; }
        public boolean isPathStyle() { return pathStyle; }
        public void setPathStyle(boolean pathStyle) { this.pathStyle = pathStyle; }
        public int getTimeoutSeconds() { return timeoutSeconds; }
        public void setTimeoutSeconds(int timeoutSeconds) { this.timeoutSeconds = timeoutSeconds; }
    }
}
