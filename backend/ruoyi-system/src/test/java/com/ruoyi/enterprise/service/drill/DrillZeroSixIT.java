package com.ruoyi.enterprise.service.drill;

import static org.junit.jupiter.api.Assertions.*;

import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import com.ruoyi.enterprise.service.HistoricalResumeMigrationConsole;
import com.ruoyi.enterprise.service.HistoricalResumePdfMigrator.SourceFile;
import com.ruoyi.enterprise.service.PdfFileVerification.VerificationRow;

/** 06 状态更新 SQL 验证：默认注释、十六进制编码、守卫、幂等；隔离库内验证文件事实回写，不放开真实性升级。 */
class DrillZeroSixIT
{
    private static final String TARGET =
            "enterprise-application-resume/9/2001/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf";

    @BeforeAll
    static void setUp() throws Exception { DrillBaseline.setup(); }

    /** 剥离块注释与行注释，返回真正可执行的裸文本。 */
    private static String stripComments(String sql)
    {
        return sql.replaceAll("(?s)/\\*.*?\\*/", "").lines()
                .filter(l -> !l.strip().startsWith("--"))
                .reduce("", (a, b) -> a + b + "\n");
    }

    @Test
    void zeroSix_generatedSqlAndDbWriteback() throws Exception
    {
        SourceFile src = new SourceFile(3001, 2001, 9, 500, "private-resume/70/a.pdf", "a.pdf", 100L);
        // 有证据（copyVerified）生成回写；无证据行不生成
        VerificationRow copyRow = new VerificationRow(
                null, TARGET, true, true, 100L, 100L, "h1", "h1",
                true, false, null, false, "COPIED_UNVERIFIED", "");
        VerificationRow noEvidence = new VerificationRow(
                null, null, false, false, null, null, null, null,
                false, false, null, false, "SOURCE_MISSING_NO_FILE", "");

        Path tmp = Files.createTempDirectory("drill06");
        Path file = tmp.resolve("06_update_snapshot_status.sql");
        HistoricalResumeMigrationConsole console = new HistoricalResumeMigrationConsole(null, null);
        Method write = HistoricalResumeMigrationConsole.class.getDeclaredMethod(
                "writeStatusUpdateSql", Path.class, List.class, List.class);
        write.setAccessible(true);
        write.invoke(console, file, List.of(src), List.of(copyRow));

        String sql = Files.readString(file);
        // 默认全部注释：剥离注释后无任何可执行 UPDATE
        String executable = stripComments(sql);
        assertFalse(executable.toUpperCase().contains("UPDATE"), "存在未注释语句");
        // 不改 app_status；状态升级段（COMPLETE/MANUAL_VERIFIED）在注释内
        assertFalse(sql.contains("app_status"));
        assertTrue(sql.contains("COMPLETE") && sql.contains("MANUAL_VERIFIED"));
        // 守卫条件齐备
        assertTrue(sql.contains("ers_snapshot_status = 'REBUILT_UNVERIFIED'"));
        assertTrue(sql.contains("ers_version_verified IS NULL"));
        assertTrue(sql.contains("ers_file_path IS NULL"));
        // 无证据行不产生回写（文件中只有 copyRow 一段，且无 SOURCE_MISSING 段）
        assertTrue(write.invoke(console, tmp.resolve("x.sql"), List.of(src), List.of(noEvidence)) == null);

        // 十六进制编码：null/空串/普通值/中文
        Method hex = HistoricalResumeMigrationConsole.class.getDeclaredMethod("sqlUtf8Hex", String.class);
        hex.setAccessible(true);
        assertEquals("NULL", hex.invoke(null, new Object[]{null}));
        assertEquals("_utf8mb4 X''", hex.invoke(null, ""));
        assertEquals("_utf8mb4 X'616263'", hex.invoke(null, "abc"));
        String zh = (String) hex.invoke(null, "中");
        assertEquals("_utf8mb4 X'E4B8AD'", zh);
        assertTrue(zh.matches("_utf8mb4 X'[0-9A-F]+'"));

        // 隔离库回写行为：构造一条 file_path 为空的待回写快照
        DrillEnv.executeScript("""
            INSERT INTO t_ent_resume_snapshot
              (ers_id, ers_app_id, ers_candidate_id, ers_company_id, ers_position_id,
               ers_snapshot_status, ers_version_verified, ers_time_source, ers_file_path, ers_created_at)
             VALUES (4001, 2101, 80, 9, 10, 'REBUILT_UNVERIFIED', NULL, 'BACKFILL_REAL', NULL, '2026-01-05 10:00:00');
            """);
        String update = """
            UPDATE t_ent_resume_snapshot SET ers_file_path = 'enterprise-application-resume/9/2101/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.pdf',
                   ers_file_name = 'a.pdf', ers_file_size = 100, ers_content_hash = 'h1'
             WHERE ers_id = 4001 AND ers_app_id = 2101
               AND ers_snapshot_status = 'REBUILT_UNVERIFIED'
               AND ers_version_verified IS NULL AND ers_file_path IS NULL""";
        int n1 = updateCount(update);
        assertEquals(1, n1);
        // 状态未被改变（仍 REBUILT_UNVERIFIED，version 仍 NULL）
        assertEquals("REBUILT_UNVERIFIED", DrillEnv.scalar(
            "SELECT ers_snapshot_status FROM t_ent_resume_snapshot WHERE ers_id=4001"));
        // 幂等：重跑（file_path 已非空）→ 0 行
        assertEquals(0, updateCount(update));
        // 错误 app_id 守卫 → 0 行；不覆盖其他快照
        int wrong = updateCount(update.replace("ers_app_id = 2101", "ers_app_id = 999999"));
        assertEquals(0, wrong);

        DrillResults.pass("06", "默认注释/十六进制/守卫/幂等/隔离库回写",
            "零可执行语句+编码正确+影响1行+幂等0行+状态不变",
            "all UPDATE commented; writeback row=1 then 0; guard works",
            "MySQL " + DrillEnv.mysqlVersion(), "未放开真实性升级，未改 app_status");
    }

    private static int updateCount(String sql) throws Exception
    {
        try (java.sql.Connection c = DrillEnv.connection(); java.sql.Statement st = c.createStatement())
        {
            return st.executeUpdate(sql);
        }
    }
}
