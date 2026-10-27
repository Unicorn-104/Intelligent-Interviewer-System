package com.ruoyi.system.service.app.pdf;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.ResumePdfProperties;

/** 私有简历附件存储，不向客户端暴露本机路径。 */
@Component
public class ResumeAttachmentStorage
{
    private static final Logger log = LoggerFactory.getLogger(ResumeAttachmentStorage.class);
    private static final String PREFIX = "private-resume-attachment/";
    private static final long MAX_SIZE = 20 * 1024 * 1024L;
    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("pdf", "doc", "docx", "jpg", "jpeg", "png");
    private final ResumePdfProperties properties;

    public record StoredAttachment(String reference, String name, long size, String contentType) { }

    public ResumeAttachmentStorage(ResumePdfProperties properties)
    {
        this.properties = properties;
    }

    public StoredAttachment store(Long userId, MultipartFile file)
    {
        requireUser(userId);
        if (file == null || file.isEmpty()) throw new ServiceException("附件不能为空");
        if (file.getSize() > MAX_SIZE) throw new ServiceException("单个附件不能超过20MB");
        String name = safeName(file.getOriginalFilename());
        String extension = extension(name);
        if (!ALLOWED_EXTENSIONS.contains(extension))
            throw new ServiceException("附件仅支持 PDF、Word、JPG 或 PNG 格式");
        String reference = PREFIX + userId + "/" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"))
                + "/" + UUID.randomUUID().toString().replace("-", "") + "." + extension;
        Path target = resolve(userId, reference);
        try
        {
            Files.createDirectories(target.getParent());
            ensureContained(target);
            Files.write(target, file.getBytes(), java.nio.file.StandardOpenOption.CREATE_NEW);
            String contentType = file.getContentType() == null || file.getContentType().isBlank()
                    ? "application/octet-stream" : file.getContentType();
            return new StoredAttachment(reference, name, file.getSize(), contentType);
        }
        catch (IOException error)
        {
            delete(userId, reference);
            throw new ServiceException("附件保存失败，请检查简历存储目录权限");
        }
    }

    public Path read(Long userId, String reference)
    {
        Path path = resolve(userId, reference);
        if (!Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS)) throw new ServiceException("附件不存在");
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
            log.warn("简历附件清理失败，请检查存储目录权限");
        }
    }

    private Path resolve(Long userId, String reference)
    {
        requireUser(userId);
        if (reference == null || !reference.matches("private-resume-attachment/" + userId
                + "/[0-9]{4}/[0-9]{2}/[0-9]{2}/[a-f0-9]{32}\\.(pdf|doc|docx|jpg|jpeg|png)"))
            throw new ServiceException("附件不存在或无权访问");
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
            if (!resolved.startsWith(root().toRealPath())) throw new ServiceException("附件文件路径无效");
        }
        catch (IOException error) { throw new ServiceException("简历附件目录无法读取"); }
    }

    private String safeName(String name)
    {
        if (name == null) return "附件.bin";
        String basename = name.replace('\\', '/');
        basename = basename.substring(basename.lastIndexOf('/') + 1).replaceAll("[\\p{Cntrl}]", "").trim();
        if (basename.isEmpty()) return "附件.bin";
        return basename.length() > 255 ? basename.substring(0, 255) : basename;
    }

    private String extension(String name)
    {
        int index = name.lastIndexOf('.');
        return index < 0 ? "" : name.substring(index + 1).toLowerCase(Locale.ROOT);
    }

    private void requireUser(Long userId)
    {
        if (userId == null || userId <= 0) throw new ServiceException("登录用户无效");
    }
}