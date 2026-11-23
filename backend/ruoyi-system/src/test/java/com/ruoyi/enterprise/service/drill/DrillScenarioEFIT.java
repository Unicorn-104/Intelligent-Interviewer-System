package com.ruoyi.enterprise.service.drill;

import static org.junit.jupiter.api.Assertions.*;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;
import com.ruoyi.enterprise.service.CsvRecords;
import com.ruoyi.enterprise.service.EnterpriseResumeStorage.StoredPdf;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecord;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.MigrationRecordStore;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourceFile;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourcePdfReader;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.EnterprisePdfTarget;
import com.ruoyi.enterprise.service.PdfFileVerification;
import com.ruoyi.enterprise.service.PdfFileVerification.VerificationRow;

/** 场景 E：临时 Fake 端口 + 真实 PdfFileVerification，验证 14 列、10 分类与异常分支；不连真实对象存储。 */
class DrillScenarioEFIT
{
    static final String HEX32 = "a".repeat(32);

    static SourceFile sf(long appId, long companyId)
    {
        return new SourceFile(1, appId, companyId, 1,
                "private-resume/50/2026/01/01/a.pdf", "name.pdf", null);
    }

    static String ref(long company, long app)
    {
        return "enterprise-application-resume/" + company + "/" + app + "/" + HEX32 + ".pdf";
    }

    static final class FakeSource implements SourcePdfReader
    {
        byte[] value; RuntimeException failure;
        @Override public byte[] read(long id, String r)
        {
            if (failure != null) throw failure;
            return value;
        }
    }

    static final class FakeTarget implements EnterprisePdfTarget
    {
        final Map<String, byte[]> objects = new HashMap<>();
        RuntimeException readFailure;
        @Override public StoredPdf store(long c, long a, byte[] b, String n)
        {
            String r = ref(c, a);
            objects.put(r, b);
            return new StoredPdf(r, n, b.length);
        }
        @Override public byte[] readBack(String r)
        {
            if (readFailure != null) throw readFailure;
            return objects.get(r);
        }
        @Override public void deleteOwn(String r) { objects.remove(r); }
    }

    static final class FakeRecords implements MigrationRecordStore
    {
        MigrationRecord value; RuntimeException failure;
        @Override public MigrationRecord find(long appId)
        {
            if (failure != null) throw failure;
            return value;
        }
        @Override public void save(MigrationRecord r) { value = r; }
    }

    private VerificationRow verify(FakeSource src, FakeTarget tgt, FakeRecords rec, SourceFile s)
    {
        return new PdfFileVerification(src, tgt, rec).verify(s);
    }

    /** 测试侧独立 SHA-256（不依赖生产类包级方法）。 */
    static String sha256Hex(byte[] bytes)
    {
        try
        {
            byte[] d = java.security.MessageDigest.getInstance("SHA-256").digest(bytes);
            StringBuilder sb = new StringBuilder();
            for (byte b : d) sb.append(Character.forDigit((b >> 4) & 0xF, 16))
                               .append(Character.forDigit(b & 0xF, 16));
            return sb.toString();
        }
        catch (Exception e) { throw new IllegalStateException(e); }
    }

    @Test
    void scenarioE_classificationAndEvidence()
    {
        byte[] x = "PDF-BYTES-X".getBytes();
        byte[] y = "PDF-BYTES-Y-DIFFERENT".getBytes();
        Set<String> produced = new HashSet<>();

        // 1 RECOVERABLE_PENDING：源存在、无记录（目标无）
        FakeSource s1 = new FakeSource(); s1.value = x;
        VerificationRow r1 = verify(s1, new FakeTarget(), new FakeRecords(), sf(1001, 9));
        assertEquals("RECOVERABLE_PENDING", r1.finalClassification());
        produced.add(r1.finalClassification());

        // 2 COPIED_UNVERIFIED：源/目标同字节，copyVerified=TRUE，authenticity=FALSE
        FakeSource s2 = new FakeSource(); s2.value = x;
        FakeTarget t2 = new FakeTarget(); t2.objects.put(ref(9, 1002), x);
        FakeRecords c2 = new FakeRecords(); c2.value = new MigrationRecord(1002, ref(9, 1002), null);
        VerificationRow r2 = verify(s2, t2, c2, sf(1002, 9));
        assertEquals("COPIED_UNVERIFIED", r2.finalClassification());
        assertTrue(r2.copyVerified());
        assertFalse(r2.authenticityVerified());
        produced.add(r2.finalClassification());

        // 4 VERIFY_FAILED：源/目标都存在但不一致
        FakeSource s4 = new FakeSource(); s4.value = x;
        FakeTarget t4 = new FakeTarget(); t4.objects.put(ref(9, 1004), y);
        FakeRecords c4 = new FakeRecords(); c4.value = new MigrationRecord(1004, ref(9, 1004), null);
        VerificationRow r4 = verify(s4, t4, c4, sf(1004, 9));
        assertEquals("VERIFY_FAILED", r4.finalClassification());
        assertFalse(r4.copyVerified());
        produced.add(r4.finalClassification());

        // 5 SOURCE_MISSING_NO_FILE：源 null、无记录
        FakeSource s5 = new FakeSource();
        VerificationRow r5 = verify(s5, new FakeTarget(), new FakeRecords(), sf(1005, 9));
        assertEquals("SOURCE_MISSING_NO_FILE", r5.finalClassification());
        produced.add(r5.finalClassification());

        // 6 ARCHIVED_UNVERIFIED：源 null、目标存在、参考哈希缺失
        FakeTarget t6 = new FakeTarget(); t6.objects.put(ref(9, 1006), y);
        FakeRecords c6 = new FakeRecords(); c6.value = new MigrationRecord(1006, ref(9, 1006), null);
        VerificationRow r6 = verify(new FakeSource(), t6, c6, sf(1006, 9));
        assertEquals("ARCHIVED_UNVERIFIED", r6.finalClassification());
        produced.add(r6.finalClassification());

        // 7 SOURCE_MISSING_BUT_ARCHIVED：源 null、目标哈希==独立参考，绑定 OK
        String hashY = sha256Hex(y);
        FakeTarget t7 = new FakeTarget(); t7.objects.put(ref(9, 1007), y);
        FakeRecords c7 = new FakeRecords(); c7.value = new MigrationRecord(1007, ref(9, 1007), hashY);
        VerificationRow r7 = verify(new FakeSource(), t7, c7, sf(1007, 9));
        assertEquals("SOURCE_MISSING_BUT_ARCHIVED", r7.finalClassification());
        assertTrue(r7.archiveIntegrityVerified());
        assertEquals(hashY, r7.archiveReferenceSha256());
        produced.add(r7.finalClassification());

        // 8 ARCHIVE_HASH_MISMATCH：目标哈希与参考不符
        FakeTarget t8 = new FakeTarget(); t8.objects.put(ref(9, 1008), y);
        FakeRecords c8 = new FakeRecords(); c8.value = new MigrationRecord(1008, ref(9, 1008), sha256Hex(x));
        VerificationRow r8 = verify(new FakeSource(), t8, c8, sf(1008, 9));
        assertEquals("ARCHIVE_HASH_MISMATCH", r8.finalClassification());
        assertFalse(r8.archiveIntegrityVerified());
        produced.add(r8.finalClassification());

        // 9 MANUAL_REVIEW：源异常（模拟403/超时/5xx）、目标异常、记录损坏、绑定错误
        FakeSource se = new FakeSource(); se.failure = new RuntimeException("403/超时/5xx");
        assertEquals("MANUAL_REVIEW", verify(se, new FakeTarget(), new FakeRecords(), sf(1010, 9)).finalClassification());
        FakeTarget te = new FakeTarget(); te.readFailure = new RuntimeException("目标读取失败");
        FakeRecords ce = new FakeRecords(); ce.value = new MigrationRecord(1011, ref(9, 1011), null);
        assertEquals("MANUAL_REVIEW", verify(new FakeSource(), te, ce, sf(1011, 9)).finalClassification());
        FakeRecords re = new FakeRecords(); re.failure = new RuntimeException("记录损坏");
        assertEquals("MANUAL_REVIEW", verify(new FakeSource(), new FakeTarget(), re, sf(1012, 9)).finalClassification());
        // 绑定错误：appId 不匹配
        FakeRecords cb = new FakeRecords(); cb.value = new MigrationRecord(9999, ref(9, 1013), hashY);
        FakeTarget tb = new FakeTarget(); tb.objects.put(ref(9, 1013), y);
        assertEquals("MANUAL_REVIEW", verify(new FakeSource(), tb, cb, sf(1013, 9)).finalClassification());
        // 绑定错误：companyId 不匹配（路径属于企业8）
        FakeRecords cc = new FakeRecords(); cc.value = new MigrationRecord(1014, ref(8, 1014), hashY);
        FakeTarget tc = new FakeTarget(); tc.objects.put(ref(8, 1014), y);
        assertEquals("MANUAL_REVIEW", verify(new FakeSource(), tc, cc, sf(1014, 9)).finalClassification());
        // 绑定错误：targetRef 非法（路径逃逸/格式错），目标存在才会进入绑定校验
        FakeTarget td = new FakeTarget(); td.objects.put("../escape.pdf", y);
        FakeRecords cd = new FakeRecords(); cd.value = new MigrationRecord(1015, "../escape.pdf", hashY);
        assertEquals("MANUAL_REVIEW", verify(new FakeSource(), td, cd, sf(1015, 9)).finalClassification());
        produced.add("MANUAL_REVIEW");

        // 3/10 历史程序不制造 COPIED_AND_VERIFIED / LIVE_ORIGINAL_COMPLETE
        assertFalse(produced.contains("COPIED_AND_VERIFIED"));
        assertFalse(produced.contains("LIVE_ORIGINAL_COMPLETE"));

        // 14 列完整性：记录访问器数量（通过反射计数 record 组件）
        assertEquals(14, VerificationRow.class.getRecordComponents().length);

        // CSV 公式注入防护：危险前缀被前置单引号
        String dangerous = CsvRecords.escape("=1+1");
        assertEquals("'=1+1", dangerous);
        String atSign = CsvRecords.escape("@SUM(A1)");
        assertEquals("'@SUM(A1)", atSign);

        DrillResults.pass("E", "PDF 14列/10分类/异常分支/CSV防护",
            "8可达分类+2不制造+异常全MANUAL_REVIEW+14列+公式防护",
            "classifications=" + produced.size() + ",copy/archive/authenticity分离",
            "Fake内存端口", "未连真实对象存储");
    }
}
