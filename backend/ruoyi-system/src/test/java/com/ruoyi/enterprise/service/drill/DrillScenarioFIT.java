package com.ruoyi.enterprise.service.drill;

import static org.junit.jupiter.api.Assertions.*;

import java.sql.SQLException;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;

/**
 * 场景 F：回滚与中途失败，真实 MySQL 8 一次性容器。
 * 先验证真实复合主键与回滚守卫2冲突（DR-3），再构造单列主键形态验证 RENAME 归档、manual-only 保护与恢复。
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class DrillScenarioFIT
{
    private static void exec(String sql) throws Exception { DrillEnv.executeScript(sql); }

    /** 仅提取存储过程定义（DROP PROCEDURE 到 DELIMITER ;），不含第一部分诊断与第五部分回滚后核验，避免顶层 SELECT 提前执行。 */
    private static String rollbackProc() throws Exception
    {
        String full = DrillMigration.load("05_rollback.sql");
        String startMarker = "DROP PROCEDURE IF EXISTS p_ent_rollback;";
        String endMarker = "DELIMITER ;";
        int start = full.indexOf(startMarker);
        int end = full.indexOf(endMarker, start) + endMarker.length();
        return full.substring(start, end);
    }

    @BeforeAll
    static void setUp() throws Exception { DrillBaseline.setup(); }

    @Test
    @Order(1)
    void f1_realCompositePkBlockedByGuard() throws Exception
    {
        // 真实表为复合三列主键（baseline），定义过程后 CALL 应被守卫2拦截
        exec(rollbackProc());
        String msg = "";
        try { exec("CALL p_ent_rollback()"); }
        catch (SQLException e) { msg = e.getMessage(); }
        assertTrue(msg.contains("单列主键"), "实际消息=" + msg);
        // 尚未 RENAME，原表仍存在且行数不变
        assertEquals(1, DrillEnv.count(
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'"));
        DrillResults.pass("F", "未重构复合主键回滚(守卫拦截)", "CALL应被守卫中止",
            msg, "MySQL " + DrillEnv.mysqlVersion(),
            "守卫2正确拦截非单列主键表，未RENAME无数据损失；重构为asr_id后由f2验证完整回滚");
    }

    @Test
    @Order(2)
    void f2_singlePkFullRollback() throws Exception
    {
        // 重建为单列主键形态（模拟可通过守卫的结构），含 llm 多版本与 manual-only 组
        exec("DROP TABLE IF EXISTS t_ai_candidate_analysis");
        exec("""
            CREATE TABLE t_ai_candidate_analysis (
              asr_id bigint NOT NULL AUTO_INCREMENT,
              asr_company_id bigint NOT NULL,
              asr_position_id bigint NOT NULL,
              asr_candidate_id bigint NOT NULL,
              asr_resume_id bigint DEFAULT NULL,
              asr_report json NOT NULL,
              asr_updated_at datetime NOT NULL,
              asr_app_id bigint DEFAULT NULL,
              asr_snapshot_id bigint DEFAULT NULL,
              asr_content_hash varchar(128) DEFAULT NULL,
              asr_source varchar(10) DEFAULT NULL,
              asr_version_status varchar(24) DEFAULT NULL,
              asr_created_at datetime DEFAULT NULL,
              PRIMARY KEY (asr_id),
              KEY idx_asr_company_position_candidate (asr_company_id, asr_position_id, asr_candidate_id),
              KEY idx_aca_candidate_updated (asr_company_id, asr_candidate_id, asr_updated_at),
              KEY idx_asr_app (asr_app_id, asr_source, asr_created_at),
              KEY idx_asr_snapshot (asr_snapshot_id),
              KEY idx_asr_company_candidate (asr_company_id, asr_candidate_id),
              KEY idx_asr_company_position (asr_company_id, asr_position_id))""");
        // 组70：两行 llm（取最新一条）；组71：manual-only；组72：一行 llm
        exec("""
            INSERT INTO t_ai_candidate_analysis
              (asr_company_id, asr_position_id, asr_candidate_id, asr_report, asr_updated_at,
               asr_source, asr_created_at)
             VALUES (9,10,70, JSON_OBJECT('v','old'), '2026-01-01 10:00:00', 'llm', '2026-01-01 10:00:00'),
                    (9,10,70, JSON_OBJECT('v','new'), '2026-02-01 10:00:00', 'llm', '2026-02-01 10:00:00'),
                    (9,10,71, JSON_OBJECT('v','m'),   '2026-02-01 10:00:00', 'manual', '2026-02-01 10:00:00'),
                    (9,10,72, JSON_OBJECT('v','l'),   '2026-03-01 10:00:00', 'llm', '2026-03-01 10:00:00');
            """);

        // 归档表已存在守卫：先占位归档表，CALL 应被拦截
        exec("CREATE TABLE t_ai_candidate_analysis_hist_20261109 (id bigint)");
        String existMsg = "";
        try { exec("CALL p_ent_rollback()"); }
        catch (SQLException e) { existMsg = e.getMessage(); }
        assertTrue(existMsg.contains("归档表已存在"), "实际=" + existMsg);
        exec("DROP TABLE t_ai_candidate_analysis_hist_20261109");

        // 正常回滚
        exec("CALL p_ent_rollback()");

        // 归档表完整保留全部 4 行（含 manual 与多版本）
        assertEquals(4, DrillEnv.count("SELECT COUNT(*) FROM t_ai_candidate_analysis_hist_20261109"));
        // 新表：组70取最新llm、组71 manual-only不写入、组72写入 → 共 2 行
        assertEquals(2, DrillEnv.count("SELECT COUNT(*) FROM t_ai_candidate_analysis"));
        // 组70 回填的是最新一条（v=new）
        assertEquals("{\"v\": \"new\"}", DrillEnv.scalar(
            "SELECT asr_report FROM t_ai_candidate_analysis WHERE asr_candidate_id=70"));
        // 新表已删迁移列、恢复旧结构
        assertEquals(0, DrillEnv.count("""
            SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
               AND column_name IN ('asr_app_id','asr_source','asr_snapshot_id')"""));
        // 新表恢复原始复合主键（PRIMARY 恰好三列，列序 company,position,candidate）
        assertEquals(3, DrillEnv.count("""
            SELECT COUNT(*) FROM information_schema.statistics
             WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
               AND index_name='PRIMARY'"""));
        assertEquals("asr_company_id", DrillEnv.scalar("""
            SELECT column_name FROM information_schema.key_column_usage
             WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
               AND constraint_name='PRIMARY' ORDER BY ordinal_position LIMIT 1"""));
        // asr_id 已删除，无残留
        assertEquals(0, DrillEnv.count("""
            SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'
               AND column_name='asr_id'"""));
        // 新表索引仅 PRIMARY 与 idx_aca_candidate_updated（两个 distinct 索引名）
        assertEquals(2, DrillEnv.count("""
            SELECT COUNT(DISTINCT index_name) FROM information_schema.statistics
             WHERE table_schema=DATABASE() AND table_name='t_ai_candidate_analysis'"""));
        // 企业快照五表未被删除
        assertEquals(5, DrillEnv.count("""
            SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema=DATABASE() AND table_name LIKE 't_ent_resume_%'"""));

        DrillResults.pass("F", "单列主键回滚/归档/manual-only/恢复",
            "归档4行零删除+新表2行+manual-only不写入+快照保留",
            "hist=4,new=2,归档守卫有效", "MySQL " + DrillEnv.mysqlVersion(),
            "RENAME 后归档表保留即中途失败可恢复证据；DDL隐式提交不可事务回滚");
    }
}
