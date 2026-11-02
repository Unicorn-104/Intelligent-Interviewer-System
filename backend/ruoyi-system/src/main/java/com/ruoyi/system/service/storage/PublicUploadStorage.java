package com.ruoyi.system.service.storage;

import java.io.InputStream;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.file.FileUploadUtils;
import com.ruoyi.common.utils.file.MimeTypeUtils;

/** 通用公开资源上传；保持旧 /profile/upload 语义，私有简历使用独立鉴权接口。 */
@Service
public class PublicUploadStorage
{
    public static final String URL_PREFIX = "/profile/storage/uploads/";
    private static final int MAX_BYTES = 50 * 1024 * 1024;
    private static final Logger log = LoggerFactory.getLogger(PublicUploadStorage.class);
    private static final Set<String> IMAGES = Set.of("jpg", "jpeg", "png", "gif", "bmp");
    private final S3FileStorage objects;

    public record Uploaded(String path, String originalName, long size, String contentType) { }

    public PublicUploadStorage(S3FileStorage objects) { this.objects = objects; }

    public Uploaded store(Long userId, MultipartFile file) throws Exception
    {
        if (userId == null || userId <= 0) throw new ServiceException("登录用户无效");
        if (file == null || file.isEmpty()) throw new ServiceException("请选择上传文件");
        String name = file.getOriginalFilename();
        if (name == null || name.isBlank() || name.length() > FileUploadUtils.DEFAULT_FILE_NAME_LENGTH)
            throw new ServiceException("文件名为空或过长");
        FileUploadUtils.assertAllowed(file, MimeTypeUtils.DEFAULT_ALLOWED_EXTENSION);
        String extension = FileUploadUtils.getExtension(file).toLowerCase(Locale.ROOT);
        String type = contentType(extension);
        if (!objects.enabled())
            return new Uploaded(FileUploadUtils.upload(RuoYiConfig.getUploadPath(), file), name, file.getSize(), type);
        byte[] bytes;
        try (InputStream input = file.getInputStream()) { bytes = input.readNBytes(MAX_BYTES + 1); }
        if (bytes.length > MAX_BYTES) throw new ServiceException("文件不能超过50MB");
        if (IMAGES.contains(extension)) AvatarStorage.validateImage(bytes, extension);
        if ("pdf".equals(extension) && (bytes.length < 5 || bytes[0] != '%' || bytes[1] != 'P'
                || bytes[2] != 'D' || bytes[3] != 'F' || bytes[4] != '-'))
            throw new ServiceException("PDF 文件头校验失败");
        String key = "uploads/" + userId + "/" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"))
                + "/" + UUID.randomUUID().toString().replace("-", "") + "." + extension;
        objects.store(key, bytes, type);
        return new Uploaded("/profile/storage/" + key, safeName(name), bytes.length, type);
    }

    public boolean isStoredPath(String path) { return path != null && path.startsWith(URL_PREFIX); }

    public Resource read(String path)
    {
        String key = key(path);
        return objects.read(objects.reference(key), MAX_BYTES);
    }

    public void deleteNewObject(Long userId, String path)
    {
        if (!isStoredPath(path)) return;
        try
        {
            String key = key(path);
            if (key.startsWith("uploads/" + userId + "/")) objects.delete(objects.reference(key));
        }
        catch (RuntimeException error) { log.warn("本次上传的对象清理失败，请核对存储状态"); }
    }

    public String contentType(String extension)
    {
        return switch (extension.toLowerCase(Locale.ROOT))
        {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "gif" -> "image/gif";
            case "bmp" -> "image/bmp";
            case "pdf" -> "application/pdf";
            case "doc" -> "application/msword";
            case "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            case "xls" -> "application/vnd.ms-excel";
            case "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            case "ppt" -> "application/vnd.ms-powerpoint";
            case "pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation";
            case "txt" -> "text/plain";
            default -> "application/octet-stream";
        };
    }

    private String key(String path)
    {
        if (!isStoredPath(path)) throw new ServiceException("上传资源引用无效");
        String key = path.substring("/profile/storage/".length());
        S3FileStorage.key(objects.reference(key));
        return key;
    }

    private String safeName(String name)
    {
        String safe = name.replace('\\', '/');
        return safe.substring(safe.lastIndexOf('/') + 1).replaceAll("[\\p{Cntrl}]", "");
    }
}
