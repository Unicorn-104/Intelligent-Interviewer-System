package com.ruoyi.system.domain.app;

import java.nio.file.Path;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;

/** 仅在后端内部传递的已授权 PDF 文件。 */
public record AppResumePdfDocument(Resource resource, String name)
{
    public AppResumePdfDocument(Path path, String name) { this(new FileSystemResource(path), name); }
}
