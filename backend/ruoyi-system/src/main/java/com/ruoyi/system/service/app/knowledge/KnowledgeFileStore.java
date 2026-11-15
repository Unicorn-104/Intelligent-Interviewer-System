package com.ruoyi.system.service.app.knowledge;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.UUID;
import org.springframework.stereotype.Component;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.system.service.storage.S3FileStorage;

/** Private originals. Local files are siblings of the publicly served profile directory. */
@Component
public class KnowledgeFileStore
{
    private final S3FileStorage s3;
    public KnowledgeFileStore(S3FileStorage s3) { this.s3 = s3; }

    public String store(long userId, String extension, byte[] bytes) throws Exception
    {
        String key = "private-knowledge/" + userId + "/" + UUID.randomUUID() + "." + extension;
        if (s3.enabled()) return s3.store(key, bytes, contentType(extension));
        Path target = resolve(userId, key);
        Files.write(target, bytes, StandardOpenOption.CREATE_NEW);
        return key;
    }

    public byte[] read(long userId, String reference) throws Exception
    {
        String key = S3FileStorage.isReference(reference) ? S3FileStorage.key(reference) : reference;
        validate(userId, key);
        if (S3FileStorage.isReference(reference)) return s3.read(reference, KnowledgeDocumentParser.MAX_BYTES).getContentAsByteArray();
        Path target = resolve(userId, key);
        if (Files.size(target) > KnowledgeDocumentParser.MAX_BYTES) throw new IllegalArgumentException("FILE_SIZE");
        return Files.readAllBytes(target);
    }

    public void delete(long userId, String reference) throws Exception
    {
        validate(userId, S3FileStorage.isReference(reference) ? S3FileStorage.key(reference) : reference);
        if (S3FileStorage.isReference(reference)) s3.delete(reference);
        else Files.deleteIfExists(resolve(userId, reference));
    }

    private void validate(long userId, String key)
    {
        if (userId <= 0 || key == null || !key.matches("private-knowledge/" + userId + "/[a-f0-9-]{36}\\.(pdf|docx|txt|md)"))
            throw new IllegalArgumentException("FILE_REFERENCE");
    }

    private Path resolve(long userId, String key) throws Exception
    {
        validate(userId, key);
        Path profile = Path.of(RuoYiConfig.getProfile()).toAbsolutePath().normalize();
        Path root = profile.resolveSibling("knowledge-files");
        Path target = root.resolve(key.substring("private-knowledge/".length())).normalize();
        Files.createDirectories(target.getParent());
        if (!target.getParent().toRealPath().startsWith(root.toRealPath())
                || Files.isSymbolicLink(root) || Files.isSymbolicLink(target)
                || (Files.exists(profile) && root.toRealPath().startsWith(profile.toRealPath())))
            throw new IllegalArgumentException("FILE_REFERENCE");
        return target;
    }

    public static String contentType(String extension)
    {
        return switch (extension) {
            case "pdf" -> "application/pdf";
            case "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            default -> "text/plain; charset=utf-8";
        };
    }
}
