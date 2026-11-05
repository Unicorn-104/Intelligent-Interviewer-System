package com.ruoyi.system.service.storage;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Iterator;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.file.FileUploadUtils;
import com.ruoyi.common.utils.file.MimeTypeUtils;

/** 头像是公开展示资源；简历等私有文件不经过此入口。 */
@Service
public class AvatarStorage
{
    public static final String URL_PREFIX = "/profile/storage/";
    private static final int MAX_BYTES = 5 * 1024 * 1024;
    private static final String KEY_PATTERN = "avatars/[1-9][0-9]*/[0-9]{4}/[0-9]{2}/[0-9]{2}/[a-f0-9]{32}\\.(jpg|jpeg|png|gif|bmp)";
    private static final Logger log = LoggerFactory.getLogger(AvatarStorage.class);
    private final S3FileStorage objects;

    public AvatarStorage(S3FileStorage objects) { this.objects = objects; }

    public String store(Long userId, MultipartFile file) throws Exception
    {
        if (userId == null || userId <= 0) throw new ServiceException("登录用户无效");
        if (file == null || file.isEmpty()) throw new ServiceException("请选择头像图片");
        if (file.getSize() > MAX_BYTES) throw new ServiceException("头像图片不能超过5MB");
        byte[] bytes;
        try (InputStream input = file.getInputStream()) { bytes = input.readNBytes(MAX_BYTES + 1); }
        if (bytes.length > MAX_BYTES) throw new ServiceException("头像图片不能超过5MB");
        String name = file.getOriginalFilename();
        String extension = name == null || !name.contains(".") ? "" : name.substring(name.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
        if (!Set.of("jpg", "jpeg", "png", "gif", "bmp").contains(extension))
            throw new ServiceException("头像仅支持 JPG、PNG、GIF 或 BMP 图片");
        validateImage(bytes, extension);
        String declaredType = file.getContentType();
        if (declaredType != null && !declaredType.isBlank()
                && !declaredType.equalsIgnoreCase(contentType(extension))
                && !("jpg".equals(extension) && declaredType.equalsIgnoreCase("image/jpg"))
                && !declaredType.equalsIgnoreCase("application/octet-stream"))
            throw new ServiceException("头像图片类型与文件内容不匹配");
        if (!objects.enabled())
            return FileUploadUtils.upload(RuoYiConfig.getAvatarPath(), file, MimeTypeUtils.IMAGE_EXTENSION, true);
        String key = "avatars/" + userId + "/" + LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM/dd"))
                + "/" + UUID.randomUUID().toString().replace("-", "") + "." + extension;
        objects.store(key, bytes, contentType(extension));
        // 不把桶名放入头像 URL，兼容旧 sys_user.avatar 的长度限制及不同部署的桶名。
        return URL_PREFIX + key;
    }

    public Resource read(String key)
    {
        if (key == null || !key.matches(KEY_PATTERN)) throw new ServiceException("头像不存在");
        return objects.read(objects.reference(key), MAX_BYTES);
    }

    public String contentType(String extension)
    {
        return switch (extension.toLowerCase(Locale.ROOT))
        {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "gif" -> "image/gif";
            case "bmp" -> "image/bmp";
            default -> throw new ServiceException("头像类型不支持");
        };
    }

    /** 只清理本次生成或当前用户旧头像引用，不处理任意 URL、私有简历或其他用户对象。 */
    public void delete(Long userId, String avatar)
    {
        if (avatar == null || avatar.isBlank() || userId == null || userId <= 0) return;
        try
        {
            if (avatar.startsWith(URL_PREFIX))
            {
                String key = avatar.substring(URL_PREFIX.length());
                if (key.matches(KEY_PATTERN) && key.startsWith("avatars/" + userId + "/"))
                    objects.delete(objects.reference(key));
                return;
            }
            if (!avatar.matches("/profile/avatar/[0-9]{4}/[0-9]{2}/[0-9]{2}/[a-zA-Z0-9_-]+\\.(jpg|jpeg|png|gif|bmp)")) return;
            Path root = Path.of(RuoYiConfig.getAvatarPath()).toAbsolutePath().normalize();
            Path target = root.resolve(avatar.substring("/profile/avatar/".length())).normalize();
            if (target.startsWith(root) && Files.exists(target) && target.toRealPath().startsWith(root.toRealPath()))
                Files.deleteIfExists(target);
        }
        catch (IOException | RuntimeException error) { log.warn("头像旧文件清理失败，请检查存储服务"); }
    }

    static void validateImage(byte[] bytes, String extension)
    {
        try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes)))
        {
            Iterator<ImageReader> readers = ImageIO.getImageReaders(input);
            if (!readers.hasNext()) throw new ServiceException("头像文件不是有效图片");
            ImageReader reader = readers.next();
            try
            {
                reader.setInput(input);
                String format = reader.getFormatName().toLowerCase(Locale.ROOT);
                String expected = "jpg".equals(extension) ? "jpeg" : extension;
                int width = reader.getWidth(0);
                int height = reader.getHeight(0);
                if (!expected.equals(format) || width <= 0 || height <= 0 || width > 8192 || height > 8192)
                    throw new ServiceException("头像格式不匹配或图片尺寸超过8192像素");
            }
            finally { reader.dispose(); }
        }
        catch (IOException error) { throw new ServiceException("头像图片读取失败"); }
    }
}
