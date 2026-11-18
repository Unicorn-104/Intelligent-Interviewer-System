package com.ruoyi.enterprise.service;

import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import com.ruoyi.enterprise.service.PdfFileVerification.VerificationRow;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.Outcome;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourceFile;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.Status;
import static org.junit.jupiter.api.Assertions.*;

class HistoricalResumeMigrationConsoleTest
{
    private static final String SRC_REF = "private-resume/7/2026/01/01/abcdef0123456789abcdef0123456789.pdf";
    private static final String TGT_REF = "enterprise-application-resume/9/100/aaa00000000000000000000000000001.pdf";
    private static final String HASH = "a".repeat(64);

    @TempDir
    Path tempDir;

    private HistoricalResumeMigrationConsole console;

    private SourceFile source()
    {
        return new SourceFile(1L, 100L, 9L, 50L, SRC_REF, "简历.pdf", 3L);
    }

    private VerificationRow archivedRow()
    {
        return new VerificationRow(SRC_REF, TGT_REF, false, true, null, 3L,
                null, HASH, false, true, HASH, false,
                "SOURCE_MISSING_BUT_ARCHIVED", "归档完整性经独立历史哈希验证");
    }

    private VerificationRow unverifiedRow()
    {
        return new VerificationRow(SRC_REF, TGT_REF, false, true, null, 3L,
                null, HASH, false, false, null, false,
                "ARCHIVED_UNVERIFIED", "无独立历史参考哈希");
    }

    @BeforeEach
    void setUp() { console = new HistoricalResumeMigrationConsole(null, null); }

    private Object invoke(String name, Class<?>[] types, Object[] args) throws Exception
    {
        Method m = HistoricalResumeMigrationConsole.class.getDeclaredMethod(name, types);
        m.setAccessible(true);
        return m.invoke(console, args);
    }

    @Test
    void manifestHasExactly14ColumnsAndRoundTripsSpecialChars() throws Exception
    {
        VerificationRow row = new VerificationRow(SRC_REF, TGT_REF, true, true, 3L, 3L,
                HASH, HASH, true, false, null, false, "COPIED_UNVERIFIED",
                "中文,逗号\"引号\n换行");
        Path file = tempDir.resolve("migration_file_verification_manifest.csv");
        invoke("writeVerificationManifest",
                new Class[]{Path.class, List.class}, new Object[]{file, List.of(row)});

        String text = Files.readString(file, StandardCharsets.UTF_8);
        List<List<String>> parsed = CsvRecords.parse(text);
        assertEquals(14, parsed.get(0).size(), "表头必须 14 列");
        assertEquals(14, parsed.get(1).size(), "数据行必须 14 列");
        assertEquals("source_path", parsed.get(0).get(0));
        assertEquals("detail", parsed.get(0).get(13));
        // 特殊字符经合规编码后可无损还原
        assertEquals("中文,逗号\"引号\n换行", parsed.get(1).get(13));
        assertEquals("TRUE", parsed.get(1).get(8));
        assertEquals("FALSE", parsed.get(1).get(9));
    }

    @Test
    void k_archivedSuccessWritesFactSqlButNeverExecutesOrUpgrades() throws Exception
    {
        Path file = tempDir.resolve("06.sql");
        invoke("writeStatusUpdateSql",
                new Class[]{Path.class, List.class, List.class},
                new Object[]{file, List.of(source()), List.of(archivedRow())});

        String sql = Files.readString(file, StandardCharsets.UTF_8);
        // 目标引用以十六进制字面量出现（不再是原始字符串）
        assertTrue(sql.contains(HistoricalResumeMigrationConsole.sqlUtf8Hex(TGT_REF)));
        assertTrue(sql.contains("ers_id = 1"));
        assertTrue(sql.contains("ers_app_id = 100"));
        assertTrue(sql.contains("REBUILT_UNVERIFIED"));
        assertTrue(sql.contains("ers_file_path IS NULL"));
        // 移除全部块注释后，不得存在任何可执行语句（所有 UPDATE 均默认注释）
        String executable = sql.replaceAll("(?s)/\\*.*?\\*/", "");
        assertFalse(executable.contains("UPDATE"));
        assertFalse(executable.contains("COMPLETE"));
        assertFalse(executable.contains("MANUAL_VERIFIED"));
    }

    @Test
    void l_noIndependentReferenceWritesNoSql() throws Exception
    {
        Path file = tempDir.resolve("06.sql");
        invoke("writeStatusUpdateSql",
                new Class[]{Path.class, List.class, List.class},
                new Object[]{file, List.of(source()), List.of(unverifiedRow())});

        String sql = Files.readString(file, StandardCharsets.UTF_8);
        String executable = sql.replaceAll("(?s)/\\*.*?\\*/", "");
        assertFalse(sql.contains("UPDATE"), "无独立参考不得生成回写");
        assertFalse(executable.contains("UPDATE"));
    }

    @Test
    void sqlUtf8HexEncodesAllDynamicInputsSafely()
    {
        assertEquals("NULL", HistoricalResumeMigrationConsole.sqlUtf8Hex(null));
        assertEquals("_utf8mb4 X''", HistoricalResumeMigrationConsole.sqlUtf8Hex(""));
        assertEquals("_utf8mb4 X'616263'", HistoricalResumeMigrationConsole.sqlUtf8Hex("abc"));
        // 中文按 UTF-8 字节
        assertEquals("_utf8mb4 X'E7AE80'", HistoricalResumeMigrationConsole.sqlUtf8Hex("简"));
        // 恶意输入（注释符/引号/反斜杠/换行/伪装 SQL）编码后只含安全字符
        String[] attacks = {
            "resume*/UPDATE t_app_record SET app_status=5",
            "a'b\"c\\d\ne", "/*", "*/", "\t", "DROP TABLE t_ent_resume_snapshot;"};
        for (String attack : attacks)
        {
            String encoded = HistoricalResumeMigrationConsole.sqlUtf8Hex(attack);
            assertTrue(encoded.matches("_utf8mb4 X'[0-9A-F]*'"), "必须为纯十六进制: " + encoded);
            assertFalse(encoded.contains("UPDATE") || encoded.contains("*/"));
        }
    }

    @Test
    void maliciousFileNameCannotEscapeCommentOrExecute() throws Exception
    {
        String evilName = "resume*/UPDATE t_app_record SET app_status=5";
        SourceFile evilSource = new SourceFile(1L, 100L, 9L, 50L, SRC_REF, evilName, 3L);
        VerificationRow archived = archivedRow();
        Path file = tempDir.resolve("06.sql");
        invoke("writeStatusUpdateSql",
                new Class[]{Path.class, List.class, List.class},
                new Object[]{file, List.of(evilSource), List.of(archived)});

        String sql = Files.readString(file, StandardCharsets.UTF_8);
        // 原始恶意文本不得出现（已被 hex 编码），块注释不被提前终止
        assertFalse(sql.contains("app_status=5"));
        assertFalse(sql.contains("*/UPDATE"));
        String executable = sql.replaceAll("(?s)/\\*.*?\\*/", "");
        assertFalse(executable.contains("UPDATE") || executable.contains("COMPLETE"));
        // 守卫仍在
        assertTrue(sql.contains("ers_app_id = 100") && sql.contains("REBUILT_UNVERIFIED"));
    }

    @Test
    void multipleRecordsGenerateBalancedCommentBlocks() throws Exception
    {
        Path file = tempDir.resolve("06.sql");
        invoke("writeStatusUpdateSql",
                new Class[]{Path.class, List.class, List.class},
                new Object[]{file, List.of(source(), source()),
                        List.of(archivedRow(), archivedRow())});
        String sql = Files.readString(file, StandardCharsets.UTF_8);
        long open = sql.lines().filter(l -> l.trim().equals("/*")).count();
        long close = sql.lines().filter(l -> l.trim().equals("*/")).count();
        assertEquals(open, close, "块注释必须成对");
        assertTrue(open >= 2);
    }

    @Test
    void manualReviewFlagsMigratedButVerifyFailed() throws Exception
    {
        Outcome migrated = new Outcome(Status.MIGRATED, 100L, TGT_REF, HASH, HASH, "迁移成功");
        VerificationRow verifyFailed = new VerificationRow(SRC_REF, TGT_REF, true, true,
                3L, 3L, HASH, "b".repeat(64), false, false, null, false,
                "VERIFY_FAILED", "哈希不一致");
        Path file = tempDir.resolve("manual_review.csv");
        invoke("writeManualReview",
                new Class[]{Path.class, List.class, List.class, List.class},
                new Object[]{file, List.of(source()), List.of(migrated), List.of(verifyFailed)});

        List<List<String>> parsed = CsvRecords.parse(Files.readString(file, StandardCharsets.UTF_8));
        assertEquals(2, parsed.size());
        assertEquals("VERIFY_FAILED", parsed.get(1).get(4));
        assertTrue(parsed.get(1).get(5).contains("复核异常"));
    }

    @Test
    void manualReviewExcludesSuccessAndIncludesNoFile() throws Exception
    {
        Outcome migrated = new Outcome(Status.MIGRATED, 100L, TGT_REF, HASH, HASH, "ok");
        VerificationRow copied = new VerificationRow(SRC_REF, TGT_REF, true, true,
                3L, 3L, HASH, HASH, true, false, null, false, "COPIED_UNVERIFIED", "一致");
        Path successFile = tempDir.resolve("mr1.csv");
        invoke("writeManualReview",
                new Class[]{Path.class, List.class, List.class, List.class},
                new Object[]{successFile, List.of(source()), List.of(migrated), List.of(copied)});
        assertEquals(1, CsvRecords.parse(Files.readString(successFile, StandardCharsets.UTF_8)).size());

        Outcome missing = new Outcome(Status.SOURCE_MISSING, 100L, null, null, null, "缺失");
        VerificationRow noFile = new VerificationRow(SRC_REF, "", false, false,
                null, null, null, null, false, false, null, false,
                "SOURCE_MISSING_NO_FILE", "源与目标均不存在");
        Path noFileOut = tempDir.resolve("mr2.csv");
        invoke("writeManualReview",
                new Class[]{Path.class, List.class, List.class, List.class},
                new Object[]{noFileOut, List.of(source()), List.of(missing), List.of(noFile)});
        List<List<String>> parsed = CsvRecords.parse(Files.readString(noFileOut, StandardCharsets.UTF_8));
        assertEquals(2, parsed.size());
        assertEquals("SOURCE_MISSING_NO_FILE", parsed.get(1).get(4));
    }
}
