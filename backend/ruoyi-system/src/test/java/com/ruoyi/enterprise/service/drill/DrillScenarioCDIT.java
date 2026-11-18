package com.ruoyi.enterprise.service.drill;

import static org.junit.jupiter.api.Assertions.*;

import java.sql.SQLException;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;

/**
 * 场景 C/D：重复投递与 AI 精确关联、结构化数据一致性与哈希校验。
 * 复用场景 A/B 已建的容器与表，仅追加数据；全部断言基于真实 MySQL 8 查询结果。
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class DrillScenarioCDIT
{
    private static void exec(String sql) throws Exception
    {
        DrillEnv.executeScript(sql);
    }

    private static String scalar(String sql) throws SQLException
    {
        return DrillEnv.scalar(sql);
    }

    @BeforeAll
    static void setUp() throws Exception
    {
        DrillBaseline.setup();
    }

    @Test
    @Order(1)
    void scenarioC_repeatedApplicationAndAiBinding() throws Exception
    {
        // 先回填基线（场景 A）的 2 条快照
        exec(DrillMigration.load("03_backfill.sql"));
        // 追加候选人与岗位
        exec("""
            INSERT INTO t_pos (pos_id, pos_company_id, pos_name) VALUES (11, 9, '岗位Y'),
                 (12, 9, '岗位Z'), (13, 9, '岗位W');
            INSERT INTO t_tal (tal_id, tal_user_id, tal_company_id)
             VALUES (53, 503, 9), (54, 504, 9), (55, 505, 9);
            """);
        // 投递：50重复同岗位(1003)、50不同岗位(1004)；53同岗位两次(1005,1006)
        exec("""
            INSERT INTO t_app_record (app_id, app_candidate_id, app_position_id, app_resume_id,
                app_status, app_created_at)
             VALUES (1003, 50, 10, 1, 1, '2026-03-01 10:00:00'),
                    (1004, 50, 11, 1, 1, '2026-03-02 10:00:00'),
                    (1005, 53, 10, 1, 0, '2026-03-03 10:00:00'),
                    (1006, 53, 10, 1, 0, '2026-03-04 10:00:00');
            """);
        // AI 行：(9,11,50)manual唯一组；(9,10,53)llm多快照组；(9,12,54)unknown无快照；(9,13,55)已MATCHED
        exec("""
            INSERT INTO t_ai_candidate_analysis (asr_company_id, asr_position_id, asr_candidate_id,
                asr_resume_id, asr_report, asr_updated_at)
             VALUES (9, 11, 50, 1, JSON_OBJECT('source','manual'), '2026-03-05 10:00:00'),
                    (9, 10, 53, 1, JSON_OBJECT('source','llm'), '2026-03-05 11:00:00'),
                    (9, 12, 54, NULL, JSON_OBJECT('source','x'), '2026-03-05 12:00:00');
            """);
        // 模拟一条已 MATCHED 的实时行（绑定值），验证不被覆盖
        exec("""
            INSERT INTO t_ai_candidate_analysis (asr_company_id, asr_position_id, asr_candidate_id,
                asr_report, asr_app_id, asr_snapshot_id, asr_version_status, asr_source)
             VALUES (9, 13, 55, JSON_OBJECT('source','llm'), 9999, 8888, 'MATCHED', 'llm');
            """);

        // 执行 03 回填
        exec(DrillMigration.load("03_backfill.sql"));

        // 4A 唯一快照组：绑定同一条快照，version=UNVERIFIED，source=manual
        assertEquals("1004", scalar(
            "SELECT asr_app_id FROM t_ai_candidate_analysis WHERE asr_company_id=9 AND asr_position_id=11 AND asr_candidate_id=50"));
        assertEquals("UNVERIFIED", scalar(
            "SELECT asr_version_status FROM t_ai_candidate_analysis WHERE asr_position_id=11 AND asr_candidate_id=50"));
        assertEquals("manual", scalar(
            "SELECT asr_source FROM t_ai_candidate_analysis WHERE asr_position_id=11 AND asr_candidate_id=50"));

        // 4B 多快照组：两 ID 保持 NULL，仅 UNVERIFIED
        assertEquals(null, scalar(
            "SELECT asr_app_id FROM t_ai_candidate_analysis WHERE asr_position_id=10 AND asr_candidate_id=53"));
        assertEquals(null, scalar(
            "SELECT asr_snapshot_id FROM t_ai_candidate_analysis WHERE asr_position_id=10 AND asr_candidate_id=53"));
        assertEquals("UNVERIFIED", scalar(
            "SELECT asr_version_status FROM t_ai_candidate_analysis WHERE asr_position_id=10 AND asr_candidate_id=53"));

        // 4C 无快照匹配：两 ID NULL，UNVERIFIED，source=unknown（x 非合法值）
        assertEquals(null, scalar(
            "SELECT asr_app_id FROM t_ai_candidate_analysis WHERE asr_position_id=12 AND asr_candidate_id=54"));
        assertEquals("UNVERIFIED", scalar(
            "SELECT asr_version_status FROM t_ai_candidate_analysis WHERE asr_position_id=12 AND asr_candidate_id=54"));
        assertEquals("unknown", scalar(
            "SELECT asr_source FROM t_ai_candidate_analysis WHERE asr_position_id=12 AND asr_candidate_id=54"));

        // MATCHED 保护：绑定值与状态不被覆盖
        assertEquals("9999", scalar(
            "SELECT asr_app_id FROM t_ai_candidate_analysis WHERE asr_position_id=13 AND asr_candidate_id=55"));
        assertEquals("8888", scalar(
            "SELECT asr_snapshot_id FROM t_ai_candidate_analysis WHERE asr_position_id=13 AND asr_candidate_id=55"));
        assertEquals("MATCHED", scalar(
            "SELECT asr_version_status FROM t_ai_candidate_analysis WHERE asr_position_id=13 AND asr_candidate_id=55"));

        // 幂等：再跑一次 03，快照总数与 AI 行数不变
        long snapBefore = DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot");
        long aiBefore = DrillEnv.count("SELECT COUNT(*) FROM t_ai_candidate_analysis");
        exec(DrillMigration.load("03_backfill.sql"));
        assertEquals(snapBefore, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot"));
        assertEquals(aiBefore, DrillEnv.count("SELECT COUNT(*) FROM t_ai_candidate_analysis"));

        DrillResults.pass("C", "重复投递AI精确关联(4A/4B/4C/MATCHED保护/幂等)",
            "唯一组绑定+多组不绑定+无组待核实+MATCHED不覆盖",
            "4A app=1004;4B NULL;4C unknown;MATCHED保留",
            "MySQL " + DrillEnv.mysqlVersion(), "真实容器执行");
    }

    /** 比较两个 JSON_ARRAY 表达式的行哈希：1=相同，0=不同。 */
    private static int hashCompare(String jsonArrayA, String jsonArrayB) throws SQLException
    {
        return Integer.parseInt(DrillEnv.scalar(
            "SELECT SHA2(CONVERT(" + jsonArrayA + " USING utf8mb4) COLLATE utf8mb4_bin,256) "
          + "= SHA2(CONVERT(" + jsonArrayB + " USING utf8mb4) COLLATE utf8mb4_bin,256)"));
    }

    @Test
    @Order(2)
    void scenarioD_hashAndMultiset() throws Exception
    {
        // D1 完全一致：哈希相同
        assertEquals(1, hashCompare("JSON_ARRAY('Java','2')", "JSON_ARRAY('Java','2')"));

        // D2 NULL vs 空串：JSON 天然区分，哈希不同
        assertEquals(0, hashCompare("JSON_ARRAY(NULL,'2')", "JSON_ARRAY('','2')"));

        // 字段边界：JSON 位置固定，'a','b' 合并歧义不存在
        assertEquals(0, hashCompare("JSON_ARRAY('a','b')", "JSON_ARRAY('ab','')"));

        // D5 大小写敏感（utf8mb4_bin）
        assertEquals(0, hashCompare("JSON_ARRAY('Java','2')", "JSON_ARRAY('java','2')"));

        // D6 尾部空格敏感
        assertEquals(0, hashCompare("JSON_ARRAY('Java','2')", "JSON_ARRAY('Java ','2')"));

        // D7 全角 vs 半角
        assertEquals(0, hashCompare("JSON_ARRAY('A','1')", "JSON_ARRAY('Ａ','１')"));

        // D8 Unicode 内容不同
        assertEquals(0, hashCompare("JSON_ARRAY('贵州','2')", "JSON_ARRAY('贵阳','2')"));

        // max_sort_length 默认 1024；哈希对完整字符串计算，不依赖排序前缀
        String msl = scalar("SELECT @@max_sort_length");
        // D9 长 TEXT（>1024 字节）整体不同，哈希不同
        assertEquals(0, hashCompare(
            "JSON_ARRAY(REPEAT('a',1100),'2')",
            "JSON_ARRAY(REPEAT('a',1101),'2')"));
        // D10 前 1024 字节相同、仅尾部不同，仍可检出
        assertEquals(0, hashCompare(
            "JSON_ARRAY(CONCAT(REPEAT('a',1024),'X'),'2')",
            "JSON_ARRAY(CONCAT(REPEAT('a',1024),'Y'),'2')"));
        // 长串长度确认
        assertEquals("1100", scalar("SELECT LENGTH(REPEAT('a',1100))"));

        // D3/D4 端到端多重集：源 Java,Java,Python vs 快照 Java,Python,Python（总数相同，计数分布不同）
        exec("INSERT INTO t_res_base (rbs_id, rbs_user_id, rbs_resume_name, rbs_status) "
            + "VALUES (2, 501, '简历乙', 1)");
        exec("""
            INSERT INTO t_ent_resume_snapshot (ers_app_id, ers_candidate_id, ers_company_id,
              ers_position_id, ers_source_resume_id, ers_snapshot_status, ers_time_source)
             VALUES (2002, 60, 9, 10, 2, 'REBUILT_UNVERIFIED', 'BACKFILL_REAL')""");
        long sid = Long.parseLong(scalar(
            "SELECT ers_id FROM t_ent_resume_snapshot WHERE ers_app_id=2002"));
        exec("INSERT INTO t_res_skill (skl_resume_id, skl_name, skl_level) "
            + "VALUES (2,'Java',3),(2,'Java',3),(2,'Python',2)");
        exec("INSERT INTO t_ent_resume_skill (esk_snapshot_id, esk_name, esk_level) "
            + "VALUES (" + sid + ",'Java',3),(" + sid + ",'Python',2),(" + sid + ",'Python',2)");

        // 8.5.4 SRC_SIDE：以源分组 g 为主，源计数>快照计数（Java 源2 vs 快照1）
        String srcSide = """
            SELECT COUNT(*) FROM (
              SELECT s.ers_id
              FROM t_ent_resume_snapshot s
              JOIN (
                SELECT k.skl_resume_id AS rid,
                       SHA2(CONVERT(JSON_ARRAY(k.skl_name, CAST(k.skl_level AS CHAR))
                         USING utf8mb4) COLLATE utf8mb4_bin,256) AS hh, COUNT(*) AS cnt_src
                  FROM t_res_skill k GROUP BY k.skl_resume_id, hh
              ) g ON g.rid=s.ers_source_resume_id
              LEFT JOIN (
                SELECT x.esk_snapshot_id AS sid,
                       SHA2(CONVERT(JSON_ARRAY(x.esk_name, CAST(x.esk_level AS CHAR))
                         USING utf8mb4) COLLATE utf8mb4_bin,256) AS hh, COUNT(*) AS cnt_snap
                  FROM t_ent_resume_skill x GROUP BY x.esk_snapshot_id, hh
              ) h ON h.sid=s.ers_id AND h.hh=g.hh
              WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified='MANUAL_VERIFIED')
                AND s.ers_snapshot_status<>'MISSING_SOURCE'
                AND (h.sid IS NULL OR g.cnt_src>h.cnt_snap)
            ) q""";
        // 8.5.4b SNAP_SIDE：以快照分组 h 为主，LEFT JOIN 源分组，快照计数>源计数（Python 快照2 vs 源1）
        String snapSide = """
            SELECT COUNT(*) FROM (
              SELECT s.ers_id
              FROM t_ent_resume_snapshot s
              JOIN (
                SELECT x.esk_snapshot_id AS sid,
                       SHA2(CONVERT(JSON_ARRAY(x.esk_name, CAST(x.esk_level AS CHAR))
                         USING utf8mb4) COLLATE utf8mb4_bin,256) AS hh, COUNT(*) AS cnt_snap
                  FROM t_ent_resume_skill x GROUP BY x.esk_snapshot_id, hh
              ) h ON h.sid=s.ers_id
              LEFT JOIN (
                SELECT k.skl_resume_id AS rid,
                       SHA2(CONVERT(JSON_ARRAY(k.skl_name, CAST(k.skl_level AS CHAR))
                         USING utf8mb4) COLLATE utf8mb4_bin,256) AS hh, COUNT(*) AS cnt_src
                  FROM t_res_skill k GROUP BY k.skl_resume_id, hh
              ) g ON g.rid=s.ers_source_resume_id AND h.hh=g.hh
              WHERE (s.ers_version_verified IS NULL OR s.ers_version_verified='MANUAL_VERIFIED')
                AND s.ers_snapshot_status<>'MISSING_SOURCE'
                AND (g.rid IS NULL OR h.cnt_snap>g.cnt_src)
            ) q""";
        assertEquals(1, DrillEnv.count(srcSide));
        assertEquals(1, DrillEnv.count(snapSide));

        // 12 个日期字段：六对子表日期列类型一致且均为 date
        long datePairs = DrillEnv.count("""
            SELECT COUNT(*) FROM (
              SELECT c.table_name, c.column_name, c.data_type
              FROM information_schema.columns c
              WHERE c.table_schema=DATABASE()
                AND c.column_name IN ('ere_start_date','ere_end_date','erw_start_date','erw_end_date',
                  'erp_start_date','erp_end_date','edu_start_date','edu_end_date',
                  'wrk_start_date','wrk_end_date','prj_start_date','prj_end_date')
                AND c.data_type='date'
            ) d""");
        assertEquals(12, datePairs);
        // 无 datetime/timestamp 混入这些日期列
        assertEquals(0, DrillEnv.count("""
            SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema=DATABASE()
               AND column_name IN ('ere_start_date','ere_end_date','erw_start_date','erw_end_date',
                 'erp_start_date','erp_end_date','edu_start_date','edu_end_date',
                 'wrk_start_date','wrk_end_date','prj_start_date','prj_end_date')
               AND data_type<>'date'"""));

        DrillResults.pass("D", "哈希边界/长TEXT/多重集/12日期",
            "NULL空串/大小写/空格/全半角/Unicode/长TEXT均可区分+多重集检出+12日期date",
            "hashCompare边界全0;8.5.4双向各1;datePairs=12;max_sort_length=" + msl,
            "MySQL " + DrillEnv.mysqlVersion(), "真实容器执行");
    }
}
