package com.ruoyi.system.config;

import java.net.URI;
import java.time.Duration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;

@Configuration
public class S3StorageConfiguration
{
    @Bean(destroyMethod = "close")
    @ConditionalOnProperty(prefix = "app.storage", name = "provider", havingValue = "s3")
    public S3Client fileStorageS3Client(FileStorageProperties properties)
    {
        FileStorageProperties.S3 settings = properties.getS3();
        URI endpoint;
        try
        {
            endpoint = URI.create(settings.getEndpoint());
            if (!("http".equals(endpoint.getScheme()) || "https".equals(endpoint.getScheme()))
                    || endpoint.getHost() == null || endpoint.getUserInfo() != null
                    || endpoint.getQuery() != null || endpoint.getFragment() != null
                    || !(endpoint.getPath().isEmpty() || "/".equals(endpoint.getPath())))
                throw new IllegalArgumentException();
        }
        catch (RuntimeException error)
        {
            throw new IllegalArgumentException("请配置有效的对象存储 S3 API 根地址，不要使用控制台地址或带凭据的 URL");
        }
        if (settings.getAccessKey() == null || settings.getAccessKey().isBlank()
                || settings.getSecretKey() == null || settings.getSecretKey().isBlank()
                || settings.getRegion() == null || settings.getRegion().isBlank()
                || settings.getBucket() == null || !settings.getBucket().matches("[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]"))
            throw new IllegalArgumentException("启用 S3 存储前请配置存储桶、区域及服务账号凭据");
        Duration timeout = Duration.ofSeconds(settings.getTimeoutSeconds());
        return S3Client.builder()
                .endpointOverride(endpoint)
                .region(Region.of(settings.getRegion()))
                .forcePathStyle(settings.isPathStyle())
                .serviceConfiguration(S3Configuration.builder().chunkedEncodingEnabled(false).build())
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(settings.getAccessKey(), settings.getSecretKey())))
                .httpClientBuilder(UrlConnectionHttpClient.builder()
                        .connectionTimeout(Duration.ofSeconds(10)).socketTimeout(timeout))
                .overrideConfiguration(config -> config.apiCallTimeout(timeout).apiCallAttemptTimeout(timeout))
                .build();
    }
}
