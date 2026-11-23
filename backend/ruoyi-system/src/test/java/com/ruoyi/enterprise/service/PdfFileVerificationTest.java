package com.ruoyi.enterprise.service;

import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.EnterprisePdfTarget;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecord;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecordStore;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourceFile;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourcePdfReader;
import com.ruoyi.enterprise.service.PdfFileVerification.VerificationRow;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PdfFileVerificationTest
{
    private static final String SRC_REF = "private-resume/7/2026/01/01/abcdef0123456789abcdef0123456789.pdf";
    private static final String TGT_REF = "enterprise-application-resume/9/100/aaa00000000000000000000000000001.pdf";
    private static final byte[] A = {1, 2, 3};
    private static final byte[] B = {9, 9, 9};

    private SourcePdfReader reader;
    private EnterprisePdfTarget target;
    private MigrationRecordStore store;
    private PdfFileVerification verification;

    private SourceFile source()
    {
        return new SourceFile(1L, 100L, 9L, 50L, SRC_REF, "简历.pdf", 3L);
    }

    private String hash(byte[] b) { return PdfFileVerification.sha256Hex(b); }

    @BeforeEach
    void setUp()
    {
        reader = mock(SourcePdfReader.class);
        target = mock(EnterprisePdfTarget.class);
        store = mock(MigrationRecordStore.class);
        verification = new PdfFileVerification(reader, target, store);
    }

    @Test
    void a_recoverablePending_sourceOnly()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(A);
        when(store.find(100L)).thenReturn(null);
        VerificationRow r = verification.verify(source());
        assertEquals("RECOVERABLE_PENDING", r.finalClassification());
        assertTrue(r.sourceExists()); assertFalse(r.targetExists());
        assertFalse(r.copyVerified()); assertFalse(r.archiveIntegrityVerified());
    }

    @Test
    void b_copiedUnverified_equalBytes()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(A);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, TGT_REF, hash(A)));
        when(target.readBack(TGT_REF)).thenReturn(A);
        VerificationRow r = verification.verify(source());
        assertEquals("COPIED_UNVERIFIED", r.finalClassification());
        assertTrue(r.copyVerified());
        assertEquals(hash(A), r.sourceSha256()); assertEquals(hash(A), r.targetSha256());
        assertFalse(r.authenticityVerified());
    }

    @Test
    void c_verifyFailed_differentBytes()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(A);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, TGT_REF, hash(A)));
        when(target.readBack(TGT_REF)).thenReturn(B);
        VerificationRow r = verification.verify(source());
        assertEquals("VERIFY_FAILED", r.finalClassification());
        assertFalse(r.copyVerified());
    }

    @Test
    void d_sourceMissingNoFile_bothAbsent()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(null);
        VerificationRow r = verification.verify(source());
        assertEquals("SOURCE_MISSING_NO_FILE", r.finalClassification());
        assertFalse(r.sourceExists()); assertFalse(r.targetExists());
        assertFalse(r.copyVerified());
    }

    @Test
    void e_sourceMissingButArchived_historyMatches()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, TGT_REF, hash(A)));
        when(target.readBack(TGT_REF)).thenReturn(A);
        VerificationRow r = verification.verify(source());
        assertEquals("SOURCE_MISSING_BUT_ARCHIVED", r.finalClassification());
        assertTrue(r.archiveIntegrityVerified());
        assertFalse(r.copyVerified());
        assertEquals(hash(A), r.archiveReferenceSha256());
        assertFalse(r.authenticityVerified());
    }

    @Test
    void f_archivedUnverified_noReference()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, TGT_REF, "  "));
        when(target.readBack(TGT_REF)).thenReturn(A);
        VerificationRow r = verification.verify(source());
        assertEquals("ARCHIVED_UNVERIFIED", r.finalClassification());
        assertFalse(r.archiveIntegrityVerified());
        assertNull(r.archiveReferenceSha256());
    }

    @Test
    void g_archiveHashMismatch()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, TGT_REF, hash(B)));
        when(target.readBack(TGT_REF)).thenReturn(A);
        VerificationRow r = verification.verify(source());
        assertEquals("ARCHIVE_HASH_MISMATCH", r.finalClassification());
        assertFalse(r.archiveIntegrityVerified());
    }

    @Test
    void h_manualReview_appIdMismatch()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(999L, TGT_REF, hash(A)));
        when(target.readBack(TGT_REF)).thenReturn(A);
        VerificationRow r = verification.verify(source());
        assertEquals("MANUAL_REVIEW", r.finalClassification());
        assertFalse(r.archiveIntegrityVerified());
    }

    @Test
    void i_manualReview_targetReadError()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, TGT_REF, hash(A)));
        when(target.readBack(TGT_REF)).thenThrow(new RuntimeException("io error"));
        VerificationRow r = verification.verify(source());
        assertEquals("MANUAL_REVIEW", r.finalClassification());
    }

    @Test
    void j_manualReview_sourceReadError()
    {
        when(reader.read(50L, SRC_REF)).thenThrow(new RuntimeException("boom"));
        VerificationRow r = verification.verify(source());
        assertEquals("MANUAL_REVIEW", r.finalClassification());
        assertFalse(r.sourceExists());
    }

    @Test
    void referenceMustNotBeSelfAttested()
    {
        // 归档参考必须来自迁移记录，而非当前目标新算哈希
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, TGT_REF, hash(A)));
        when(target.readBack(TGT_REF)).thenReturn(A);
        VerificationRow r = verification.verify(source());
        assertEquals(hash(A), r.archiveReferenceSha256());
        // 参考哈希来源是 store，而非 target 计算结果
        verify(store).find(100L);
    }

    @Test
    void verificationIsReadOnly()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(A);
        verification.verify(source());
        verifyNoMoreInteractions(target);
        verify(store, never()).save(any());
    }

    @Test
    void companyIdMismatch_isManualReview()
    {
        String otherCompany = "enterprise-application-resume/8/100/bbb00000000000000000000000000002.pdf";
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, otherCompany, hash(A)));
        when(target.readBack(otherCompany)).thenReturn(A);
        assertEquals("MANUAL_REVIEW", verification.verify(source()).finalClassification());
    }

    @Test
    void targetBelongsToOtherApplication_isManualReview()
    {
        String otherApp = "enterprise-application-resume/9/200/bbb00000000000000000000000000003.pdf";
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, otherApp, hash(A)));
        when(target.readBack(otherApp)).thenReturn(A);
        assertEquals("MANUAL_REVIEW", verification.verify(source()).finalClassification());
    }

    @Test
    void malformedTargetRef_isManualReview()
    {
        String bad = "enterprise-application-resume/9/100/../escape.pdf";
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenReturn(new MigrationRecord(100L, bad, hash(A)));
        // 底层仍可读，触发绑定校验（引用不匹配正则）
        when(target.readBack(bad)).thenReturn(A);
        assertEquals("MANUAL_REVIEW", verification.verify(source()).finalClassification());
    }

    @Test
    void recordFindThrows_isManualReviewNotMissing()
    {
        when(reader.read(50L, SRC_REF)).thenReturn(null);
        when(store.find(100L)).thenThrow(new RuntimeException("corrupt records"));
        VerificationRow r = verification.verify(source());
        assertEquals("MANUAL_REVIEW", r.finalClassification());
        assertTrue(r.detail().contains("迁移记录读取失败"));
    }
}
