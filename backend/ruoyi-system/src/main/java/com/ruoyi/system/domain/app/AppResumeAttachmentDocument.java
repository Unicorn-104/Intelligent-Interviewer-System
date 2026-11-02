package com.ruoyi.system.domain.app;

import java.nio.file.Path;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;

/** 仅在后端内部传递的已授权简历附件。 */
public record AppResumeAttachmentDocument(Resource resource, String name, String contentType)
{
    public AppResumeAttachmentDocument(Path path, String name, String contentType)
    {
        this(new FileSystemResource(path), name, contentType);
    }
}
