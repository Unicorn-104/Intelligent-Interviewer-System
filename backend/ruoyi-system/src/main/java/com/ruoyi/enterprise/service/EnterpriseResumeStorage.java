package com.ruoyi.enterprise.service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.storage.S3FileStorage;

/**
 * 企业投递简历 PDF 存储。
 *
 * <p>独立命名空间 {@code enterprise-application-resume/{companyId}/{appId}/{uuid}.pdf}，
 * 与 C-App 的 private-resume 物理分离；对象以随机 UUID 创建、CREATE_NEW 语义，不覆盖。
 * 复用 {@link S3FileStorage} 与本地文件框架，不另起炉灶；调用方负责企业/岗位权限校验。</p>
 */
@Component
public class EnterpriseResumeStorage
{
    private static final Logger log = LoggerFactory.getLogger(EnterpriseResumeStorage.class);
    private static final String PREFIX = "enterprise-application-resume/";
    private static final int MAX_SIZE_BYTES = 10 * 1024 * 1024;
    /** 本地引用形态：enterprise-application-resume/企业/投递/32位uuid.pdf */
    private static final Pattern LOCAL_REF = Pattern.compile(
            "enterprise-application-resume/[1-9][0-9]*/[1-9][0-9]*/[a-f0-9]{32}\\.pdf");

    private final S3FileStorage objectStorage;

    public record StoredPdf(String reference, String name, long size) { }

    public EnterpriseResumeStorage() { this(null); }

    @Autowired
    public EnterpriseResumeStorage(S3FileStorage objectStorage)
    {
        this.objectStorage = objectStorage;
    }

    /**
     * 复制为企业不可变对象。
     *
     * @param companyId 企业ID
     * @param appId 投递ID
     * @param bytes PDF 字节
     * @param originalName 原始文件名（仅用于展示名）
     */
    public StoredPdf store(Long companyId, Long appId, byte[] bytes, String originalName)
    {
        requireIds(companyId, appId);
        if (bytes == null || bytes.length == 0) throw new ServiceException("简历文件内容为空");
        if (bytes.length > MAX_SIZE_BYTES) throw new ServiceException("原始简历过大");
        String reference = PREFIX + companyId + "/" + appId + "/"
                + UUID.randomUUID().toString().replace("-", "") + ".pdf";
        if (objectStorage != null && objectStorage.enabled())
        {
            String stored = objectStorage.store(reference, bytes, "application/pdf");
            return new StoredPdf(stored, safeName(originalName), bytes.length);
        }
        Path target = resolve(reference);
        try
        {
            Files.createDirectories(target.getParent());
            Files.write(target, bytes, java.nio.file.StandardOpenOption.CREATE_NEW);
            return new StoredPdf(reference, safeName(originalName), bytes.length);
        }
        catch (IOException error)
        {
            delete(reference);
            throw new ServiceException("企业简历 PDF 保存失败，请检查存储目录权限");
        }
    }

    /** 读取企业 PDF；调用方必须先完成企业/岗位权限校验。 */
    public Resource read(String reference)
    {
        if (S3FileStorage.isReference(reference))
        {
            if (objectStorage == null) throw new ServiceException("对象存储未配置");
            return objectStorage.read(reference, MAX_SIZE_BYTES);
        }
        validateLocal(reference);
        Path path = resolve(reference);
        if (!Files.isRegularFile(path))
            throw new ServiceException("企业简历 PDF 不存在", S3FileStorage.NOT_FOUND_CODE);
        return new FileSystemResource(path);
    }

    /** 受控删除：仅用于企业数据生命周期流程，不响应 C-App 简历删除。 */
    public void delete(String reference)
    {
        if (reference == null) return;
        if (S3FileStorage.isReference(reference))
        {
            try
            {
                if (objectStorage == null) throw new ServiceException("对象存储未配置");
                objectStorage.delete(reference);
            }
            catch (RuntimeException error)
            {
                log.warn("企业简历 PDF 对象清理失败，请检查存储服务和归属");
            }
            return;
        }
        if (!LOCAL_REF.matcher(reference).matches()) return;
        try { Files.deleteIfExists(resolve(reference)); }
        catch (IOException error) { log.warn("企业简历 PDF 清理失败，请检查存储目录权限"); }
    }

    private Path resolve(String reference)
    {
        validateLocal(reference);
        Path publicRoot = Path.of(RuoYiConfig.getProfile()).toAbsolutePath().normalize();
        Path root = publicRoot.resolveSibling("enterprise-resume").normalize();
        return root.resolve(reference.substring(PREFIX.length())).normalize();
    }

    private void validateLocal(String reference)
    {
        if (reference == null || !LOCAL_REF.matcher(reference).matches())
            throw new ServiceException("企业简历文件引用无效");
    }

    private void requireIds(Long companyId, Long appId)
    {
        if (companyId == null || companyId <= 0 || appId == null || appId <= 0)
            throw new ServiceException("企业或投递标识无效");
    }

    private String safeName(String name)
    {
        if (name == null || name.isBlank()) return "简历.pdf";
        String basename = name.replace('\\', '/');
        basename = basename.substring(basename.lastIndexOf('/') + 1)
                .replaceAll("[\\p{Cntrl}]", "").trim();
        if (basename.isEmpty()) return "简历.pdf";
        return basename.length() > 255 ? basename.substring(0, 251) + ".pdf" : basename;
    }
}
