package com.ruoyi.system.domain.app;

import java.nio.file.Path;

/** 仅在后端内部传递的已授权 PDF 文件。 */
public record AppResumePdfDocument(Path path, String name) { }
