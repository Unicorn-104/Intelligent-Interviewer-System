package com.ruoyi.enterprise.service.drill;

import static org.junit.jupiter.api.Assertions.*;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.sql.SQLException;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;

/**
 * 场景 H（DR-3 独立验收）：同一企业/岗位/候选人的多版本追加式分析。
 *
 * <p>H1 验证复合三列主键在 DB 层阻断第二条同三元组 INSERT（方案 A 不可行的物理证据，测试本身通过）；
 * H2 执行 DR3 主键重构后，验证基线 1 行 + 新增两条 llm + 一条 manual 共 4 行共存、不覆盖、
 * 可按 app_id/snapshot_id 精确查询、最新分析确定性排序；
 * H3/H4 回归 asr_id 精确更新、来源/投递隔离与同时间戳排序稳定性。本类需数据库容器，
 * 本轮离线授权阶段不运行，状态记 NOT_RUN。</p>
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class DrillScenarioHIT
{
    private static final String TRIPLE =
        "asr_company_id=9 AND asr_position_id=10 AND asr_candidate_id=50";

    private static void exec(String sql) throws Exception { DrillEnv.executeScript(sql); }

    @BeforeAll
    static void setUp() throws Exception { DrillBaseline.setup(); }

    @Test
    @Order(1)
    void h1_compositePkBlocksSecondInsert() throws Exception
    {
        // 基线已有 1 行 (9,10,50)；再插同三元组 llm 应被主键拒绝
        String msg = "";
        try
        {
            exec("""
                INSERT INTO t_ai_candidate_analysis
                  (asr_company_id, asr_position_id, asr_candidate_id, asr_report,
                   asr_updated_at, asr_source, asr_app_id, asr_created_at)
                VALUES (9,10,50, JSON_OBJECT('v','second'), now(), 'llm', 1002, now())""");
        }
        catch (SQLException e) { msg = e.getMessage(); }
        // 预期内阻断：异常被捕获、断言通过，测试方法本身 PASS（不是失败）
        assertTrue(msg.contains("Duplicate entry"), "实际消息=" + msg);
        // 仍只有基线 1 行，新报告未写入
        assertEquals(1, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ai_candidate_analysis WHERE " + TRIPLE));
        DrillResults.pass("H", "复合主键追加(方案A阻断)", "第二条同三元组INSERT应被拒绝",
            "Duplicate entry 已捕获，仍仅基线1行", "MySQL " + DrillEnv.mysqlVersion(),
            "预期内物理阻断：复合主键强制每组一行，证明方案A无法追加，需方案B");
    }

    @Test
    @Order(2)
    void h2_rebuildAllowsThreeVersions() throws Exception
    {
        // 加载并执行 DR3 主键重构（定义过程 + CALL）
        String dr3 = Files.readString(
            DrillMigration.DIR.resolve("DR3_主键重构_待审核.sql"), StandardCharsets.UTF_8);
        exec(dr3);
        exec("CALL p_dr3_pk_rebuild()");
        // 新主键为单列 asr_id
        assertEquals("asr_id", DrillEnv.scalar("""
            SELECT column_name FROM information_schema.key_column_usage
             WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
               AND constraint_name='PRIMARY' ORDER BY ordinal_position LIMIT 1"""));

        // 模拟 03 来源回填：基线历史行 JSON 内 source=llm，补齐派生字段 asr_source（报告内容不变）
        exec("UPDATE t_ai_candidate_analysis SET asr_source='llm' WHERE asr_source IS NULL");

        // 同一三元组连续写入：llm#1、llm#2、manual#1（不同时间/投递，报告各自独立）
        exec("""
            INSERT INTO t_ai_candidate_analysis
              (asr_company_id, asr_position_id, asr_candidate_id, asr_report, asr_updated_at,
               asr_source, asr_app_id, asr_snapshot_id, asr_version_status, asr_created_at)
            VALUES
              (9,10,50, JSON_OBJECT('v','llm1'), '2026-03-01 10:00:00', 'llm',
                 1001, 9001, 'MATCHED', '2026-03-01 10:00:00'),
              (9,10,50, JSON_OBJECT('v','llm2'), '2026-04-01 10:00:00', 'llm',
                 1002, 9002, 'MATCHED', '2026-04-01 10:00:00'),
              (9,10,50, JSON_OBJECT('v','manual1'), '2026-04-02 10:00:00', 'manual',
                 1001, 9001, NULL, '2026-04-02 10:00:00')""");

        // 该三元组共 4 行（基线 1 + 新 3），三版本共存、无覆盖
        assertEquals(4, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ai_candidate_analysis WHERE " + TRIPLE));
        assertEquals(3, DrillEnv.count("""
            SELECT COUNT(*) FROM t_ai_candidate_analysis
             WHERE asr_company_id=9 AND asr_position_id=10 AND asr_candidate_id=50 AND asr_source='llm'"""));
        assertEquals(1, DrillEnv.count("""
            SELECT COUNT(*) FROM t_ai_candidate_analysis
             WHERE asr_company_id=9 AND asr_position_id=10 AND asr_candidate_id=50 AND asr_source='manual'"""));

        // 旧报告未被覆盖
        assertEquals("{\"v\": \"llm1\"}", DrillEnv.scalar("""
            SELECT asr_report FROM t_ai_candidate_analysis
             WHERE asr_source='llm' AND asr_app_id=1001 AND asr_snapshot_id=9001"""));

        // 按 app_id 精确查询不串用：app=1002 仅 1 条 llm2
        assertEquals(1, DrillEnv.count("""
            SELECT COUNT(*) FROM t_ai_candidate_analysis
             WHERE asr_company_id=9 AND asr_position_id=10 AND asr_candidate_id=50 AND asr_app_id=1002"""));

        // 按 snapshot_id 精确查询（9001 对应 llm1 与 manual1 共 2 条）
        assertEquals(2, DrillEnv.count("""
            SELECT COUNT(*) FROM t_ai_candidate_analysis WHERE asr_snapshot_id=9001"""));

        // 最新 llm 确定性排序取到 llm2（含 asr_id 兜底）
        assertEquals("{\"v\": \"llm2\"}", DrillEnv.scalar("""
            SELECT asr_report FROM t_ai_candidate_analysis
             WHERE asr_company_id=9 AND asr_position_id=10 AND asr_candidate_id=50 AND asr_source='llm'
             ORDER BY asr_created_at DESC, asr_updated_at DESC, asr_id DESC LIMIT 1"""));

        // 最新 manual 取到 manual1（含 asr_id 兜底）
        assertEquals("{\"v\": \"manual1\"}", DrillEnv.scalar("""
            SELECT asr_report FROM t_ai_candidate_analysis
             WHERE asr_company_id=9 AND asr_position_id=10 AND asr_candidate_id=50 AND asr_source='manual'
             ORDER BY asr_created_at DESC, asr_updated_at DESC, asr_id DESC LIMIT 1"""));

        DrillResults.pass("H", "多版本追加/精确绑定/确定性排序",
            "基线1+新增2llm+1manual共4行共存，不覆盖，按app_id/snapshot_id精确查询",
            "group=4,llm=3,manual=1", "MySQL " + DrillEnv.mysqlVersion(),
            "重构后DB约束层支持追加式；写入与回写均按asr_id/app_id精确，排序含asr_id兜底");
    }

    @Test
    @Order(3)
    void h3_preciseUpdateAndSourceIsolation() throws Exception
    {
        // 进入回归前该三元组仍为 4 行
        assertEquals(4, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ai_candidate_analysis WHERE " + TRIPLE));

        // 取 llm2 的 asr_id（app=1002 唯一 llm），按 asr_id 精确更新
        long llm2Id = Long.parseLong(DrillEnv.scalar("""
            SELECT asr_id FROM t_ai_candidate_analysis
             WHERE asr_app_id=1002 AND asr_source='llm'"""));
        exec("UPDATE t_ai_candidate_analysis SET asr_report=JSON_OBJECT('v','llm2-updated') "
            + "WHERE asr_id=" + llm2Id);

        // 仅该行变化
        assertEquals("{\"v\": \"llm2-updated\"}", DrillEnv.scalar(
            "SELECT asr_report FROM t_ai_candidate_analysis WHERE asr_id=" + llm2Id));
        // 不同 app_id 隔离：app=1001 的 llm1 未受影响
        assertEquals("{\"v\": \"llm1\"}", DrillEnv.scalar("""
            SELECT asr_report FROM t_ai_candidate_analysis
             WHERE asr_source='llm' AND asr_app_id=1001 AND asr_snapshot_id=9001"""));
        // llm 更新不影响 manual：manual1 报告不变
        assertEquals("{\"v\": \"manual1\"}", DrillEnv.scalar("""
            SELECT asr_report FROM t_ai_candidate_analysis WHERE asr_source='manual'"""));

        // 取 llm1 的 asr_id 再更新，验证 manual 反向仍不被影响
        long llm1Id = Long.parseLong(DrillEnv.scalar("""
            SELECT asr_id FROM t_ai_candidate_analysis
             WHERE asr_source='llm' AND asr_app_id=1001 AND asr_snapshot_id=9001"""));
        exec("UPDATE t_ai_candidate_analysis SET asr_report=JSON_OBJECT('v','llm1-updated') "
            + "WHERE asr_id=" + llm1Id);
        assertEquals("{\"v\": \"manual1\"}", DrillEnv.scalar("""
            SELECT asr_report FROM t_ai_candidate_analysis WHERE asr_source='manual'"""));

        // 旧的非唯一三元组条件会命中全部 4 行（证明其会批量覆盖），asr_id 条件仅命中 1 行
        assertEquals(4, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ai_candidate_analysis WHERE " + TRIPLE));
        assertEquals(1, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ai_candidate_analysis WHERE asr_id=" + llm2Id));

        DrillResults.pass("H", "asr_id精确更新/来源与投递隔离",
            "精确更新只影响目标行，llm与manual互不影响，三元组不批量覆盖",
            "tripleHits=4,asrIdHits=1", "MySQL " + DrillEnv.mysqlVersion(),
            "验证非唯一三元组UPDATE的批量覆盖风险，asr_id定位安全");
    }

    @Test
    @Order(4)
    void h4_tieTimestampDeterministicOrdering() throws Exception
    {
        // 新增两条 created_at/updated_at 完全相同的 llm（仅 asr_id 不同）
        exec("""
            INSERT INTO t_ai_candidate_analysis
              (asr_company_id, asr_position_id, asr_candidate_id, asr_report, asr_updated_at,
               asr_source, asr_app_id, asr_created_at)
            VALUES
              (9,10,50, JSON_OBJECT('v','tieA'), '2026-05-01 10:00:00', 'llm',
                 1003, '2026-05-01 10:00:00'),
              (9,10,50, JSON_OBJECT('v','tieB'), '2026-05-01 10:00:00', 'llm',
                 1004, '2026-05-01 10:00:00')""");

        // 含 asr_id 兜底的最新排序，两次执行结果一致（排序稳定）
        String latestSql = """
            SELECT asr_report FROM t_ai_candidate_analysis
             WHERE asr_company_id=9 AND asr_position_id=10 AND asr_candidate_id=50 AND asr_source='llm'
             ORDER BY asr_created_at DESC, asr_updated_at DESC, asr_id DESC LIMIT 1""";
        String first = DrillEnv.scalar(latestSql);
        String second = DrillEnv.scalar(latestSql);
        assertEquals(first, second, "同时间戳排序必须稳定");
        // 最新应为 tieB（其 asr_id 较大）
        assertEquals("{\"v\": \"tieB\"}", first);

        DrillResults.pass("H", "同时间戳asr_id确定性排序",
            "时间戳相同时按asr_id DESC稳定取最新", "tieB稳定命中",
            "MySQL " + DrillEnv.mysqlVersion(),
            "asr_id作为最终排序条件，消除同时间戳不确定性");
    }
}
