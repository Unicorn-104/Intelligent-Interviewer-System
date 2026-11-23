package com.ruoyi.enterprise.service;

import java.security.MessageDigest;

/**
 * 历史投递 PDF 独立迁移核心逻辑。
 *
 * <p>不依赖 Spring 容器与数据库，通过三个端口接口（源读取、企业目标、迁移记录）完成单条迁移，
 * 便于纯 Mockito 单测。安全约束：不删除源 PDF、不覆盖既有企业对象（目标 store 为 CREATE_NEW 语义）、
 * 不自动标记 COMPLETE、缺失源仅列入人工核查、核验失败只清理本工具本次新建的孤儿对象。</p>
 */
public class HistoricalResumePdfMigrator
{
    /** 单条迁移结果状态。 */
    public enum Status
    {
        /** 成功复制并通过完整性核验 */
        MIGRATED,
        /** 幂等命中：已有记录且目标核验通过 */
        SKIPPED_IDEMPOTENT,
        /** 源 PDF 缺失或为空，需人工核查 */
        SOURCE_MISSING,
        /** 实际大小与清单期望不一致，需人工核查 */
        SIZE_MISMATCH,
        /** 目标读回哈希与源不一致，已清理本次新建对象 */
        VERIFY_FAILED,
        /** 读写异常，可安全重试 */
        FAILED
    }

    /** 迁移清单中的一条工作项，列对齐 03_backfill.sql 步骤 5 输出。 */
    public record SourceFile(long snapshotId, long appId, long companyId, long sourceResumeId,
            String sourceRef, String sourceName, Long expectedSize) {}

    /** 迁移结果。 */
    public record Outcome(Status status, Long appId, String targetRef,
            String sourceSha256, String targetSha256, String detail) {}

    /** 持久化的成功迁移记录，用于跨进程幂等。 */
    public record MigrationRecord(long appId, String targetRef, String sourceSha256) {}

    /** 源 PDF 读取端口；文件缺失返回 null，异常向上抛出以归类为 FAILED。 */
    public interface SourcePdfReader
    {
        byte[] read(long sourceResumeId, String sourceRef);
    }

    /** 企业目标存储端口；复用 EnterpriseResumeStorage 适配。 */
    public interface EnterprisePdfTarget
    {
        EnterpriseResumeStorage.StoredPdf store(long companyId, long appId, byte[] bytes, String originalName);
        byte[] readBack(String targetRef);
        /** 仅删除本工具本次新建、且核验失败的孤儿对象，不删除任何既有对象或源文件。 */
        void deleteOwn(String targetRef);
    }

    /** 迁移记录存储端口。 */
    public interface MigrationRecordStore
    {
        MigrationRecord find(long appId);
        void save(MigrationRecord record);
    }

    private final SourcePdfReader sourceReader;
    private final EnterprisePdfTarget target;
    private final MigrationRecordStore recordStore;

    public HistoricalResumePdfMigrator(SourcePdfReader sourceReader, EnterprisePdfTarget target,
            MigrationRecordStore recordStore)
    {
        this.sourceReader = sourceReader;
        this.target = target;
        this.recordStore = recordStore;
    }

    /** 迁移单条工作项，全程不产生对源文件与既有对象的破坏。 */
    public Outcome migrateOne(SourceFile source)
    {
        // 1) 幂等：已有成功记录则读回目标核验，一致即跳过；不一致则重新迁移
        MigrationRecord existing = recordStore.find(source.appId());
        if (existing != null && existing.targetRef() != null)
        {
            byte[] present = safeReadTarget(existing.targetRef());
            if (present != null && sha256Hex(present).equals(existing.sourceSha256()))
            {
                return new Outcome(Status.SKIPPED_IDEMPOTENT, source.appId(), existing.targetRef(),
                        existing.sourceSha256(), existing.sourceSha256(), "已存在且目标完整性核验通过");
            }
        }

        // 2) 读取源 PDF
        byte[] sourceBytes;
        try
        {
            sourceBytes = sourceReader.read(source.sourceResumeId(), source.sourceRef());
        }
        catch (RuntimeException error)
        {
            return new Outcome(Status.FAILED, source.appId(), null, null, null, "读取源文件异常，可安全重试");
        }
        if (sourceBytes == null || sourceBytes.length == 0)
        {
            return new Outcome(Status.SOURCE_MISSING, source.appId(), null, null, null,
                    "源 PDF 缺失或为空，列入人工核查，禁止伪造");
        }

        // 3) 大小核验（清单提供期望值时）
        if (source.expectedSize() != null && source.expectedSize() != sourceBytes.length)
        {
            return new Outcome(Status.SIZE_MISMATCH, source.appId(), null, null, null,
                    "源文件实际大小与清单记录不一致，列入人工核查");
        }
        String sourceHash = sha256Hex(sourceBytes);

        // 4) 写入企业独立对象（CREATE_NEW 不覆盖）
        EnterpriseResumeStorage.StoredPdf stored;
        try
        {
            stored = target.store(source.companyId(), source.appId(), sourceBytes, source.sourceName());
        }
        catch (RuntimeException error)
        {
            return new Outcome(Status.FAILED, source.appId(), null, sourceHash, null,
                    "写入企业对象失败，可安全重试");
        }

        // 5) 读回目标并做哈希核验
        byte[] targetBytes = safeReadTarget(stored.reference());
        String targetHash = targetBytes == null ? null : sha256Hex(targetBytes);
        if (targetBytes == null || !sourceHash.equals(targetHash))
        {
            safeDeleteOwn(stored.reference());
            return new Outcome(Status.VERIFY_FAILED, source.appId(), stored.reference(), sourceHash, targetHash,
                    "目标完整性核验未通过，已清理本次新建对象，可重试");
        }

        // 6) 成功并持久化记录（记录写失败不影响已成功迁移，重跑时凭目标核验仍可识别）
        try
        {
            recordStore.save(new MigrationRecord(source.appId(), stored.reference(), sourceHash));
        }
        catch (RuntimeException ignored) { }
        return new Outcome(Status.MIGRATED, source.appId(), stored.reference(), sourceHash, targetHash,
                "迁移成功并通过完整性核验");
    }

    /**
     * dry-run 只读预检：不写任何目标、不写迁移记录，仅验证源可读、大小一致并计算源哈希，
     * 返回该条是否可迁移。target 端口在该路径下完全不被调用。
     */
    public Outcome plan(SourceFile source)
    {
        byte[] sourceBytes;
        try
        {
            sourceBytes = sourceReader.read(source.sourceResumeId(), source.sourceRef());
        }
        catch (RuntimeException error)
        {
            return new Outcome(Status.FAILED, source.appId(), null, null, null,
                    "dry-run：读取源异常，未写入任何对象");
        }
        if (sourceBytes == null || sourceBytes.length == 0)
        {
            return new Outcome(Status.SOURCE_MISSING, source.appId(), null, null, null,
                    "dry-run：源 PDF 缺失或为空，未写入任何对象");
        }
        if (source.expectedSize() != null && source.expectedSize() != sourceBytes.length)
        {
            return new Outcome(Status.SIZE_MISMATCH, source.appId(), null, null, null,
                    "dry-run：实际大小与清单不一致，未写入任何对象");
        }
        return new Outcome(Status.MIGRATED, source.appId(), null, sha256Hex(sourceBytes), null,
                "dry-run：可迁移，未写入任何企业对象");
    }

    private byte[] safeReadTarget(String ref)
    {
        try { return target.readBack(ref); }
        catch (RuntimeException error) { return null; }
    }

    private void safeDeleteOwn(String ref)
    {
        try { target.deleteOwn(ref); }
        catch (RuntimeException ignored) { }
    }

    private static String sha256Hex(byte[] bytes)
    {
        try
        {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
            StringBuilder sb = new StringBuilder(digest.length * 2);
            for (byte b : digest)
            {
                sb.append(Character.forDigit((b >> 4) & 0xF, 16));
                sb.append(Character.forDigit(b & 0xF, 16));
            }
            return sb.toString();
        }
        catch (Exception error)
        {
            throw new IllegalStateException("SHA-256 计算失败", error);
        }
    }
}
