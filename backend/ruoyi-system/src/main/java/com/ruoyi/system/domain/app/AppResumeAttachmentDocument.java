package com.ruoyi.system.domain.app;

import java.nio.file.Path;

/** 仅在后端内部传递的已授权简历附件。 */
public record AppResumeAttachmentDocument(Path path, String name, String contentType) { }