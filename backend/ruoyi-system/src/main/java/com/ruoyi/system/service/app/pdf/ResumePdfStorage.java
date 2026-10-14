package com.ruoyi.system.service.app.pdf;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.ResumePdfProperties;

/** 原 PDF 以随机文件名保存，仅返回业务接口，不公开本机目录。 */
@Component
public class ResumePdfStorage
{
    private static final Logger log = LoggerFactory.getLogger(ResumePdfStorage.class);
    private static final String PREFIX = "private-resume/";
    private final ResumePdfProperties properties;

    public record StoredPdf(String reference, String name, long size) { }

    public ResumePdfStorage(ResumePdfProperties properties) { this.properties = properties; }

    public StoredPdf store(Long userId, byte[] bytes, String originalName)
    {
        requireUser(userId);
        String reference = PREFIX + userId + "/" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"))
                + "/" + UUID.randomUUID().toString().replace("-", "") + ".pdf";
        Path target = resolve(userId, reference);
        try
        {
            Files.createDirectories(target.getParent());
            ensureContained(target);
            Files.write(target, bytes, java.nio.file.StandardOpenOption.CREATE_NEW);
            return new StoredPdf(reference, safeName(originalName), bytes.length);
        }
        catch (IOException error)
        {
            delete(userId, reference);
            throw new ServiceException("PDF 保存失败，请检查简历存储目录权限");
        }
    }

    public Path read(Long userId, String reference)
    {
        // 兼容其他客户端已保存的旧资源；仍先由简历服务校验所有权。
        if (reference != null && reference.startsWith("/profile/"))
        {
            requireUser(userId);
            Path publicRoot = Path.of(RuoYiConfig.getProfile()).toAbsolutePath().normalize();
            Path legacy = publicRoot.resolve(reference.substring("/profile/".length())).normalize();
            try
            {
                if (!legacy.startsWith(publicRoot) || !Files.isRegularFile(legacy, LinkOption.NOFOLLOW_LINKS)
                        || !legacy.getFileName().toString().toLowerCase(java.util.Locale.ROOT).endsWith(".pdf")
                        || !legacy.toRealPath().startsWith(publicRoot.toRealPath()))
                    throw new ServiceException("原始 PDF 不存在或无权访问");
                return legacy;
            }
            catch (IOException error) { throw new ServiceException("原始 PDF 无法读取"); }
        }
        Path path = resolve(userId, reference);
        if (!Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS)) throw new ServiceException("原始 PDF 不存在");
        ensureContained(path);
        return path;
    }

    public void delete(Long userId, String reference)
    {
        if (reference == null || !reference.startsWith(PREFIX + userId + "/")) return;
        try
        {
            Path path = resolve(userId, reference);
            ensureContained(path);
            Files.deleteIfExists(path);
        }
        catch (IOException | RuntimeException error)
        {
            log.warn("简历 PDF 清理失败，请检查存储目录权限");
        }
    }

    private Path resolve(Long userId, String reference)
    {
        requireUser(userId);
        if (reference == null || !reference.matches("private-resume/" + userId + "/[0-9]{4}/[0-9]{2}/[0-9]{2}/[a-f0-9]{32}\\.pdf"))
            throw new ServiceException("原始 PDF 不存在或无权访问");
        return root().resolve(reference.substring(PREFIX.length())).normalize();
    }

    private Path root()
    {
        String profile = RuoYiConfig.getProfile();
        if (profile == null || profile.isBlank()) throw new ServiceException("请先配置 ruoyi.profile 上传目录");
        Path publicRoot = Path.of(profile).toAbsolutePath().normalize();
        Path root = properties.getStorageDirectory().isBlank() ? publicRoot.resolveSibling("resume-pdf")
                : Path.of(properties.getStorageDirectory()).toAbsolutePath().normalize();
        if (root.startsWith(publicRoot)) throw new ServiceException("简历存储目录不能位于公开上传目录内");
        try
        {
            if (Files.exists(root) && Files.exists(publicRoot) && root.toRealPath().startsWith(publicRoot.toRealPath()))
                throw new ServiceException("简历存储目录不能指向公开上传目录");
        }
        catch (IOException error) { throw new ServiceException("简历存储目录无法读取"); }
        return root;
    }

    private void ensureContained(Path path)
    {
        try
        {
            Path resolved = Files.exists(path) ? path.toRealPath() : path.getParent().toRealPath();
            if (!resolved.startsWith(root().toRealPath())) throw new ServiceException("简历文件路径无效");
        }
        catch (IOException error) { throw new ServiceException("简历文件目录无法读取"); }
    }

    private void requireUser(Long userId)
    {
        if (userId == null || userId <= 0) throw new ServiceException("登录用户无效");
    }

    private String safeName(String name)
    {
        if (name == null) return "简历.pdf";
        String basename = name.replace('\\', '/');
        basename = basename.substring(basename.lastIndexOf('/') + 1).replaceAll("[\\p{Cntrl}]", "").trim();
        return basename.length() > 255 ? basename.substring(0, 251) + ".pdf" : basename;
    }
}
