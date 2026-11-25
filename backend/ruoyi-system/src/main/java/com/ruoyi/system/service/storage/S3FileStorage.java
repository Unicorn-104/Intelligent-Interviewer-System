package com.ruoyi.system.service.storage;

import java.io.IOException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.FileStorageProperties;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.core.exception.SdkException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;

/** 仅接受服务器生成的对象引用，不接受任意 URL；桶保持私有，由业务接口鉴权。 */
@Component
public class S3FileStorage
{
    // 临时诊断日志：定位头像读取失败的真实根因（诊断后可移除）
    private static final Logger diagLog = LoggerFactory.getLogger("S3_DIAG");
    private final FileStorageProperties properties;
    private final ObjectProvider<S3Client> clients;

    public S3FileStorage(FileStorageProperties properties, ObjectProvider<S3Client> clients)
    {
        this.properties = properties;
        this.clients = clients;
    }

    public boolean enabled() { return properties.getProvider() == FileStorageProperties.Provider.S3; }
    public static boolean isReference(String reference) { return reference != null && reference.startsWith("s3:"); }

    /** 明确“对象不存在”的错误码（404 语义）；与 403/超时/5xx 等不确定失败区分，调用方按码判断而非消息文本。 */
    public static final int NOT_FOUND_CODE = 404;

    public static String key(String reference) { return location(reference)[1]; }

    public String reference(String key)
    {
        String reference = "s3:" + properties.getS3().getBucket() + "/" + key;
        location(reference);
        return reference;
    }

    public String store(String key, byte[] bytes, String contentType)
    {
        String bucket = properties.getS3().getBucket();
        String reference = reference(key);
        try
        {
            client().putObject(request -> request.bucket(bucket).key(key).contentType(contentType),
                    RequestBody.fromBytes(bytes));
            return reference;
        }
        catch (SdkException error)
        {
            throw new ServiceException("文件上传至对象存储失败，请稍后重试");
        }
    }

    public Resource read(String reference, int maxBytes)
    {
        String[] location = location(reference);
        diagLog.info("read start reference={}, bucket={}, key={}, maxBytes={}",
                reference, location[0], location[1], maxBytes);
        try (ResponseInputStream<GetObjectResponse> input = client().getObject(
                request -> request.bucket(location[0]).key(location[1])))
        {
            Long length = input.response().contentLength();
            diagLog.info("getObject ok declaredLength={}, contentType={}",
                    length, input.response().contentType());
            if (length != null && length > maxBytes)
            {
                input.abort();
                throw new ServiceException("存储文件超过允许大小");
            }
            byte[] bytes = input.readNBytes(maxBytes + 1);
            diagLog.info("readNBytes returned bytes={}", bytes.length);
            if (bytes.length > maxBytes)
            {
                input.abort();
                throw new ServiceException("存储文件超过允许大小");
            }
            if (length != null && length >= 0 && bytes.length != length)
            {
                diagLog.warn("incomplete read declared={}, actual={}", length, bytes.length);
                throw new ServiceException("存储文件读取不完整，请稍后重试");
            }
            return new ByteArrayResource(bytes);
        }
        catch (IOException | SdkException error)
        {
            // 临时诊断：打印真实根因堆栈，区分 NoSuchKey 与其他失败
            diagLog.error("read FAILED " + error.getClass().getName(), error);
            // 仅明确的 S3 NoSuchKey（404）标记为“不存在”；403/超时/5xx/网络等保持不确定失败
            if (error instanceof NoSuchKeyException)
                throw new ServiceException("存储对象不存在", NOT_FOUND_CODE);
            throw new ServiceException("存储文件暂时无法读取");
        }
    }

    public void delete(String reference)
    {
        String[] location = location(reference);
        try
        {
            client().deleteObject(request -> request.bucket(location[0]).key(location[1]));
        }
        catch (SdkException error)
        {
            throw new ServiceException("对象存储文件清理失败");
        }
    }

    private S3Client client()
    {
        S3Client client = clients.getIfAvailable();
        if (client == null) throw new ServiceException("对象存储未启用，无法访问已保存的云端文件");
        return client;
    }

    private static String[] location(String reference)
    {
        // 保留上传、简历、企业快照和个人知识库各自的受限命名空间。
        // enterprise-application-resume/企业/投递/uuid.pdf
        if (reference == null || !reference.matches("s3:[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]/"
                + "(?:(?:private-resume|private-resume-attachment|avatars|uploads)/[1-9][0-9]*/"
                + "[0-9]{4}/[0-9]{2}/[0-9]{2}/[a-f0-9]{32}\\.(?:pdf|doc|docx|jpg|jpeg|png|gif|bmp|xls|xlsx|ppt|pptx|txt|rar|zip|gz|bz2|mp4|avi|rmvb)"
                + "|enterprise-application-resume/[1-9][0-9]*/[1-9][0-9]*/[a-f0-9]{32}\\.pdf"
                + "|private-knowledge/[1-9][0-9]*/[a-f0-9-]{36}\\.(?:pdf|docx|txt|md))"))
            throw new ServiceException("对象文件引用无效");
        return reference.substring(3).split("/", 2);
    }
}
