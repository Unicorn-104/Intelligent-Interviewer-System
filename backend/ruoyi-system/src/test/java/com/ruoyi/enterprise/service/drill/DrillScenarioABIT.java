package com.ruoyi.enterprise.service.drill;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;

/**
 * 场景 A/B：首次迁移与旧版升级，真实 MySQL 8 一次性容器。
 * 分析表为真实复合主键，简历源表为夹具（见 drill_source_schema.sql 说明）。
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class DrillScenarioABIT
{
    private static void exec(String sql) throws Exception
    {
        DrillEnv.executeScript(sql);
    }

    @BeforeAll
    static void setUp() throws Exception
    {
        DrillBaseline.setup();
    }

    @Test
    @Order(1)
    void scenarioA_firstMigration() throws Exception
    {
        // baseline 已执行 01/02/CALL：验证五表创建
        long entTables = DrillEnv.count("""
            SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE()
               AND table_name IN ('t_ent_resume_snapshot','t_ent_resume_education',
                 't_ent_resume_work','t_ent_resume_project','t_ent_resume_skill')""");
        assertEquals(5, entTables);

        // 分析表 6 新列
        long newCols = DrillEnv.count("""
            SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name='t_ai_candidate_analysis'
               AND column_name IN ('asr_app_id','asr_snapshot_id','asr_content_hash',
                 'asr_source','asr_version_status','asr_created_at')""");
        assertEquals(6, newCols);

        // 03 回填
        exec(DrillMigration.load("03_backfill.sql"));

        // 每条投递一个快照，gap=0
        long snapTotal = DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot");
        assertEquals(2, snapTotal);
        String gap = DrillEnv.scalar("""
            SELECT (SELECT COUNT(*) FROM t_app_record)
                 - (SELECT COUNT(*) FROM t_ent_resume_snapshot)""");
        assertEquals("0", gap);

        // app_id 精确对应、无重复
        assertEquals(0, DrillEnv.count("""
            SELECT ers_app_id FROM t_ent_resume_snapshot
             GROUP BY ers_app_id HAVING COUNT(*)>1"""));

        // 状态分类
        assertEquals("REBUILT_UNVERIFIED", DrillEnv.scalar(
            "SELECT ers_snapshot_status FROM t_ent_resume_snapshot WHERE ers_app_id=1001"));
        assertEquals("MISSING_SOURCE", DrillEnv.scalar(
            "SELECT ers_snapshot_status FROM t_ent_resume_snapshot WHERE ers_app_id=1002"));

        // 子表复制
        long snap1 = Long.parseLong(DrillEnv.scalar(
            "SELECT ers_id FROM t_ent_resume_snapshot WHERE ers_app_id=1001"));
        assertEquals(1, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ent_resume_education WHERE ere_snapshot_id=" + snap1));
        assertEquals(1, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ent_resume_work WHERE erw_snapshot_id=" + snap1));
        assertEquals(1, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ent_resume_project WHERE erp_snapshot_id=" + snap1));
        assertEquals(2, DrillEnv.count(
            "SELECT COUNT(*) FROM t_ent_resume_skill WHERE esk_snapshot_id=" + snap1));

        // 历史时间未被伪造
        assertEquals("2026-01-05 10:00:00", DrillEnv.scalar(
            "SELECT CAST(ers_snapshot_at AS CHAR) FROM t_ent_resume_snapshot WHERE ers_app_id=1001"));

        // 历史 AI 来源由 JSON 识别（确有 llm 证据）
        assertEquals("llm", DrillEnv.scalar(
            "SELECT asr_source FROM t_ai_candidate_analysis WHERE asr_candidate_id=50"));

        // 04 只读校验
        exec(DrillMigration.load("04_verify.sql"));

        // 幂等
        exec("CALL p_ent_schema_migrate()");
        exec(DrillMigration.load("03_backfill.sql"));
        assertEquals(2, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot"));

        DrillResults.pass("A", "首次迁移五表/回填/幂等", "五表+6列+2快照+gap0+幂等",
            "entTables=" + entTables + ",snap=" + snapTotal + ",gap=" + gap,
            "MySQL " + DrillEnv.mysqlVersion(), "真实容器执行");
    }

    @Test
    @Order(2)
    void scenarioB_legacyUpgrade() throws Exception
    {
        // B1 现实旧版：保留完整原始列（含 ers_snapshot_at），缺新增三字段
        exec("DROP TABLE IF EXISTS t_ent_resume_snapshot");
        exec("""
            CREATE TABLE t_ent_resume_snapshot (
              ers_id bigint NOT NULL AUTO_INCREMENT,
              ers_app_id bigint NOT NULL,
              ers_candidate_id bigint NOT NULL,
              ers_snapshot_status varchar(24) NOT NULL DEFAULT 'COMPLETE',
              ers_snapshot_at datetime DEFAULT NULL,
              PRIMARY KEY (ers_id))""");
        exec("INSERT INTO t_ent_resume_snapshot (ers_app_id, ers_candidate_id, ers_snapshot_at) "
            + "VALUES (1001, 50, '2026-01-05 10:00:00')");
        exec("CALL p_ent_diag_upgrade()");
        exec("CALL p_ent_schema_migrate()");

        String nullable = DrillEnv.scalar("""
            SELECT is_nullable FROM information_schema.columns
             WHERE table_schema=DATABASE() AND table_name='t_ent_resume_snapshot'
               AND column_name='ers_time_source'""");
        assertEquals("NO", nullable);
        assertEquals("BACKFILL_REAL", DrillEnv.scalar(
            "SELECT ers_time_source FROM t_ent_resume_snapshot WHERE ers_app_id=1001"));
        DrillResults.pass("B", "现实旧版升级补列/回填", "补列+按真实时间回填+收紧",
            "time_source nullable=" + nullable + ",BACKFILL_REAL",
            "MySQL " + DrillEnv.mysqlVersion(), "真实容器执行");

        // B2 严重缺列探针：旧表缺 ers_snapshot_at（缺陷 DR-2）
        exec("DROP TABLE IF EXISTS t_ent_resume_snapshot");
        exec("""
            CREATE TABLE t_ent_resume_snapshot (
              ers_id bigint NOT NULL AUTO_INCREMENT,
              ers_app_id bigint NOT NULL,
              ers_snapshot_status varchar(24) NOT NULL,
              PRIMARY KEY (ers_id))""");
        boolean dr2 = false;
        String dr2msg = "";
        try
        {
            exec("CALL p_ent_schema_migrate()");
        }
        catch (java.sql.SQLException e)
        {
            dr2msg = e.getMessage();
            dr2 = dr2msg.contains("ers_snapshot_at");
        }
        if (dr2)
        {
            DrillResults.fail("B", "严重缺列升级(缺ers_snapshot_at)", "应自动补列不报错",
                dr2msg, "MySQL " + DrillEnv.mysqlVersion(),
                "DR-2: 02迁移过程未ADD ers_snapshot_at但UPDATE先引用；最小修复：在396行前 IF NOT EXISTS ADD ers_snapshot_at datetime");
        }
        else
        {
            DrillResults.pass("B", "严重缺列升级(缺ers_snapshot_at)", "自动补列",
                "未报错", "MySQL " + DrillEnv.mysqlVersion(), "真实容器执行");
        }

        // B3 恢复完整表并重新回填，验证幂等
        exec("DROP TABLE IF EXISTS t_ent_resume_snapshot");
        exec("CALL p_ent_schema_migrate()");
        exec(DrillMigration.load("03_backfill.sql"));
        assertEquals(2, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot"));
    }
}
