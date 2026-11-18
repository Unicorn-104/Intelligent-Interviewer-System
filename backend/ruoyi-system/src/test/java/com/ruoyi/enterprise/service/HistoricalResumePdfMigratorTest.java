package com.ruoyi.enterprise.service;

import java.security.MessageDigest;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.EnterprisePdfTarget;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecord;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecordStore;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.Outcome;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourceFile;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourcePdfReader;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.Status;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class HistoricalResumePdfMigratorTest
{
    private static final String SOURCE_REF = "private-resume/7/2026/01/01/abcdef0123456789abcdef0123456789.pdf";
    private static final String OLD_TARGET = "enterprise-application-resume/9/100/old0000000000000000000000000001.pdf";
    private static final byte[] BYTES = {1, 2, 3};

    private SourcePdfReader reader;
    private EnterprisePdfTarget target;
    private MigrationRecordStore recordStore;
    private HistoricalResumePdfMigrator migrator;

    private SourceFile source()
    {
        return new SourceFile(1L, 100L, 9L, 50L, SOURCE_REF, "简历.pdf", 3L);
    }

    private EnterpriseResumeStorage.StoredPdf newStored()
    {
        return new EnterpriseResumeStorage.StoredPdf(
                "enterprise-application-resume/9/100/new0000000000000000000000000002.pdf",
                "简历.pdf", 3);
    }

    private static String sha256(byte[] bytes)
    {
        try
        {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) sb.append(String.format("%02x", b));
            return sb.toString();
        }
        catch (Exception e) { throw new IllegalStateException(e); }
    }

    @BeforeEach
    void setUp()
    {
        reader = mock(SourcePdfReader.class);
        target = mock(EnterprisePdfTarget.class);
        recordStore = mock(MigrationRecordStore.class);
        migrator = new HistoricalResumePdfMigrator(reader, target, recordStore);
    }

    @Test
    void successfulMigrationVerifiesAndSavesRecord()
    {
        EnterpriseResumeStorage.StoredPdf stored = newStored();
        when(reader.read(50L, SOURCE_REF)).thenReturn(BYTES);
        when(target.store(9L, 100L, BYTES, "简历.pdf")).thenReturn(stored);
        when(target.readBack(stored.reference())).thenReturn(BYTES);

        Outcome outcome = migrator.migrateOne(source());
        assertEquals(Status.MIGRATED, outcome.status());
        assertEquals(sha256(BYTES), outcome.sourceSha256());
        verify(recordStore).save(argThat(r -> r.appId() == 100L
                && r.targetRef().equals(stored.reference())
                && r.sourceSha256().equals(sha256(BYTES))));
        verify(target, never()).deleteOwn(any());
    }

    @Test
    void idempotentWhenRecordAndTargetVerifyPass()
    {
        when(recordStore.find(100L)).thenReturn(new MigrationRecord(100L, OLD_TARGET, sha256(BYTES)));
        when(target.readBack(OLD_TARGET)).thenReturn(BYTES);

        Outcome outcome = migrator.migrateOne(source());
        assertEquals(Status.SKIPPED_IDEMPOTENT, outcome.status());
        verify(reader, never()).read(anyLong(), anyString());
        verify(target, never()).store(anyLong(), anyLong(), any(), anyString());
    }

    @Test
    void corruptIdempotentTargetTriggersRemigration()
    {
        EnterpriseResumeStorage.StoredPdf stored = newStored();
        when(recordStore.find(100L)).thenReturn(new MigrationRecord(100L, OLD_TARGET, "stale-hash"));
        when(target.readBack(OLD_TARGET)).thenReturn(new byte[]{9});
        when(reader.read(50L, SOURCE_REF)).thenReturn(BYTES);
        when(target.store(9L, 100L, BYTES, "简历.pdf")).thenReturn(stored);
        when(target.readBack(stored.reference())).thenReturn(BYTES);

        assertEquals(Status.MIGRATED, migrator.migrateOne(source()).status());
    }

    @Test
    void missingSourceIsFlaggedWithoutWritingTarget()
    {
        when(reader.read(50L, SOURCE_REF)).thenReturn(null);
        Outcome outcome = migrator.migrateOne(source());
        assertEquals(Status.SOURCE_MISSING, outcome.status());
        verify(target, never()).store(anyLong(), anyLong(), any(), anyString());
        verify(recordStore, never()).save(any());
    }

    @Test
    void sizeMismatchIsFlaggedForManualReview()
    {
        when(reader.read(50L, SOURCE_REF)).thenReturn(new byte[]{1, 2});
        assertEquals(Status.SIZE_MISMATCH, migrator.migrateOne(source()).status());
        verify(target, never()).store(anyLong(), anyLong(), any(), anyString());
    }

    @Test
    void verifyFailureDeletesOnlyOwnNewObject()
    {
        EnterpriseResumeStorage.StoredPdf stored = newStored();
        when(reader.read(50L, SOURCE_REF)).thenReturn(BYTES);
        when(target.store(9L, 100L, BYTES, "简历.pdf")).thenReturn(stored);
        when(target.readBack(stored.reference())).thenReturn(new byte[]{9, 9, 9});

        Outcome outcome = migrator.migrateOne(source());
        assertEquals(Status.VERIFY_FAILED, outcome.status());
        verify(target).deleteOwn(stored.reference());
        verify(recordStore, never()).save(any());
    }

    @Test
    void sourceReadExceptionIsRetryableFailure()
    {
        when(reader.read(50L, SOURCE_REF)).thenThrow(new RuntimeException("boom"));
        assertEquals(Status.FAILED, migrator.migrateOne(source()).status());
        verify(target, never()).store(anyLong(), anyLong(), any(), anyString());
    }

    @Test
    void targetStoreExceptionIsRetryableFailure()
    {
        when(reader.read(50L, SOURCE_REF)).thenReturn(BYTES);
        when(target.store(9L, 100L, BYTES, "简历.pdf")).thenThrow(new RuntimeException("boom"));
        assertEquals(Status.FAILED, migrator.migrateOne(source()).status());
        verify(recordStore, never()).save(any());
    }

    @Test
    void planMarksMigratableWithHashAndNeverTouchesTargetOrRecord()
    {
        when(reader.read(50L, SOURCE_REF)).thenReturn(BYTES);

        Outcome outcome = migrator.plan(source());

        assertEquals(Status.MIGRATED, outcome.status());
        assertEquals(sha256(BYTES), outcome.sourceSha256());
        assertNull(outcome.targetRef());
        // dry-run 关键：目标存储与迁移记录完全不被调用
        verifyNoInteractions(target);
        verify(recordStore, never()).save(any());
    }

    @Test
    void planFlagsMissingSourceWithoutWrites()
    {
        when(reader.read(50L, SOURCE_REF)).thenReturn(null);
        assertEquals(Status.SOURCE_MISSING, migrator.plan(source()).status());
        verifyNoInteractions(target);
    }

    @Test
    void planFlagsSizeMismatchWithoutWrites()
    {
        when(reader.read(50L, SOURCE_REF)).thenReturn(new byte[]{1, 2});
        assertEquals(Status.SIZE_MISMATCH, migrator.plan(source()).status());
        verifyNoInteractions(target);
    }

    @Test
    void planReadExceptionIsFailureWithoutWrites()
    {
        when(reader.read(50L, SOURCE_REF)).thenThrow(new RuntimeException("boom"));
        assertEquals(Status.FAILED, migrator.plan(source()).status());
        verifyNoInteractions(target);
    }
}
