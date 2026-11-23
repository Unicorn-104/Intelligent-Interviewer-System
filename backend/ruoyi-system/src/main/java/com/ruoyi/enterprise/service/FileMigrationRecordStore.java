package com.ruoyi.enterprise.service;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecord;

/**
 * 基于本地 CSV 文件的迁移记录存储，支持跨进程/重跑幂等。
 *
 * <p>每行格式：{@code appId,targetRef,sourceSha256}；统一用 {@link CsvRecords} 解析与编码，
 * 即使引用将来出现逗号/引号也能正确处理。采用追加写入（崩溃安全），
 * 加载时同一 appId 以最后一条为准。</p>
 */
public class FileMigrationRecordStore implements HistoricalResumePdfMigrator.MigrationRecordStore
{
    private final Path file;
    private final Map<Long, MigrationRecord> records = new HashMap<>();

    public FileMigrationRecordStore(Path file)
    {
        this.file = file;
        load();
    }

    private void load()
    {
        if (!Files.isRegularFile(file)) return;
        try
        {
            List<List<String>> rows = CsvRecords.parse(Files.readString(file, StandardCharsets.UTF_8));
            for (List<String> parts : rows)
            {
                String first = parts.isEmpty() ? "" : parts.get(0).trim();
                if (first.isEmpty() || first.startsWith("#")) continue;
                if (parts.size() != 3)
                    throw new IllegalStateException("迁移记录行字段数不为 3，请核对 " + file);
                long appId = Long.parseLong(parts.get(0).trim());
                records.put(appId, new MigrationRecord(appId, parts.get(1), parts.get(2)));
            }
        }
        catch (IOException error)
        {
            throw new IllegalStateException("读取迁移记录失败", error);
        }
    }

    @Override
    public synchronized MigrationRecord find(long appId)
    {
        return records.get(appId);
    }

    @Override
    public synchronized void save(MigrationRecord record)
    {
        try
        {
            Files.createDirectories(file.getParent());
            String line = CsvRecords.format(java.util.List.of(
                    String.valueOf(record.appId()), record.targetRef(), record.sourceSha256()));
            Files.writeString(file, line + System.lineSeparator(),
                    StandardCharsets.UTF_8, StandardOpenOption.CREATE, StandardOpenOption.APPEND);
            records.put(record.appId(), record);
        }
        catch (IOException error)
        {
            throw new IllegalStateException("写入迁移记录失败", error);
        }
    }
}
