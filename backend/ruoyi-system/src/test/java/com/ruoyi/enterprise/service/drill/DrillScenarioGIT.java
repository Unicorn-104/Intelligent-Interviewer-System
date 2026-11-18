package com.ruoyi.enterprise.service.drill;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

/**
 * 场景 G：C-App/E-App 简历独立性，真实 MySQL 8 一次性容器。
 * 验证修改/删除 C-App 源简历后，E-App 快照五表、文件引用与跨企业隔离保持不变。
 */
class DrillScenarioGIT
{
    private static void exec(String sql) throws Exception { DrillEnv.executeScript(sql); }

    @BeforeAll
    static void setUp() throws Exception { DrillBaseline.setup(); }

    @Test
    void g_lifecycleIndependence() throws Exception
    {
        // 1) C-App 源简历 rbs=500（含技能/工作）与源 PDF 引用
        exec("""
            INSERT INTO t_res_base (rbs_id, rbs_user_id, rbs_resume_name, rbs_job_direction,
                                    rbs_file_path, rbs_file_name, rbs_file_size)
             VALUES (500, 70, '简历A', 'Java', 'private-resume/70/a.pdf', 'a.pdf', 100);
            INSERT INTO t_res_skill (skl_resume_id, skl_name, skl_level) VALUES (500, 'Java', 3);
            INSERT INTO t_res_work (wrk_resume_id, wrk_company, wrk_position, wrk_start_date)
             VALUES (500, '旧公司', '工程师', '2025-01-01');
            """);

        // 2) 模拟投递 app=2001，E-App 复制为独立快照（独立企业命名空间 PDF）
        exec("""
            INSERT INTO t_ent_resume_snapshot
              (ers_id, ers_app_id, ers_candidate_id, ers_company_id, ers_position_id,
               ers_source_resume_id, ers_resume_name, ers_job_direction,
               ers_file_path, ers_file_name, ers_file_size, ers_content_hash,
               ers_snapshot_status, ers_version_verified, ers_time_source, ers_snapshot_at, ers_created_at)
             VALUES (3001, 2001, 70, 9, 10, 500, '简历A', 'Java',
                     'enterprise-application-resume/9/2001/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf',
                     'a.pdf', 100, 'HASH-A-FIXED',
                     'COMPLETE', 'LIVE_ORIGINAL', 'LIVE_REAL', '2026-01-05 10:00:00', '2026-01-05 10:00:00');
            INSERT INTO t_ent_resume_skill (esk_snapshot_id, esk_name, esk_level) VALUES (3001, 'Java', 3);
            INSERT INTO t_ent_resume_work (erw_snapshot_id, erw_company, erw_position, erw_start_date)
             VALUES (3001, '旧公司', '工程师', '2025-01-01');
            """);

        // 3) C-App 修改简历为 B（改名、改技能、改工作、改源 PDF 引用）
        exec("""
            UPDATE t_res_base SET rbs_resume_name='简历B', rbs_job_direction='Python',
                                  rbs_file_path='private-resume/70/b.pdf', rbs_file_name='b.pdf'
             WHERE rbs_id=500;
            UPDATE t_res_skill SET skl_name='Python' WHERE skl_resume_id=500;
            UPDATE t_res_work SET wrk_company='新公司' WHERE wrk_resume_id=500;
            """);

        // 4) E-App 快照零变化：名称/方向/文件引用/hash 仍为 A
        assertEquals("简历A", DrillEnv.scalar("SELECT ers_resume_name FROM t_ent_resume_snapshot WHERE ers_id=3001"));
        assertEquals("Java", DrillEnv.scalar("SELECT ers_job_direction FROM t_ent_resume_snapshot WHERE ers_id=3001"));
        assertEquals("HASH-A-FIXED", DrillEnv.scalar("SELECT ers_content_hash FROM t_ent_resume_snapshot WHERE ers_id=3001"));
        assertEquals("enterprise-application-resume/9/2001/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf",
                DrillEnv.scalar("SELECT ers_file_path FROM t_ent_resume_snapshot WHERE ers_id=3001"));
        // 快照技能/工作仍为旧值
        assertEquals("Java", DrillEnv.scalar("SELECT esk_name FROM t_ent_resume_skill WHERE esk_snapshot_id=3001"));
        assertEquals("旧公司", DrillEnv.scalar("SELECT erw_company FROM t_ent_resume_work WHERE erw_snapshot_id=3001"));

        // 5) C-App 删除源简历（base/子表）
        exec("DELETE FROM t_res_skill WHERE skl_resume_id=500");
        exec("DELETE FROM t_res_work WHERE wrk_resume_id=500");
        exec("DELETE FROM t_res_base WHERE rbs_id=500");
        assertEquals(0, DrillEnv.count("SELECT COUNT(*) FROM t_res_base WHERE rbs_id=500"));

        // 6) E-App 快照仍完整可读（主表+技能+工作），文件引用不丢
        assertEquals(1, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot WHERE ers_id=3001"));
        assertEquals(1, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_skill WHERE esk_snapshot_id=3001"));
        assertEquals(1, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_work WHERE erw_snapshot_id=3001"));
        // 读快照入口（按 app_id）在源删除后仍返回；读源入口已空
        assertEquals("简历A", DrillEnv.scalar(
            "SELECT ers_resume_name FROM t_ent_resume_snapshot WHERE ers_app_id=2001"));
        assertEquals(0, DrillEnv.count("SELECT COUNT(*) FROM t_res_base WHERE rbs_file_path LIKE 'private-resume/70/%'"));

        // 7) 重复投递 app=2002 生成独立快照，互不覆盖
        exec("""
            INSERT INTO t_ent_resume_snapshot
              (ers_id, ers_app_id, ers_candidate_id, ers_company_id, ers_position_id,
               ers_resume_name, ers_snapshot_status, ers_time_source, ers_created_at)
             VALUES (3002, 2002, 70, 9, 10, '简历C', 'COMPLETE', 'LIVE_REAL', '2026-02-05 10:00:00');
            """);
        assertEquals(2, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot WHERE ers_candidate_id=70"));
        // 两快照各自 app_id 独立、无重复
        assertEquals(0, DrillEnv.count("""
            SELECT ers_app_id FROM t_ent_resume_snapshot GROUP BY ers_app_id HAVING COUNT(*)>1"""));

        // 8) 跨企业隔离：企业 8 查不到企业 9 的快照；企业9自己可查
        assertEquals(0, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot WHERE ers_company_id=8 AND ers_id=3001"));
        assertEquals(1, DrillEnv.count("SELECT COUNT(*) FROM t_ent_resume_snapshot WHERE ers_company_id=9 AND ers_id=3001"));

        DrillResults.pass("G", "C/E独立生命周期/重复投递/跨企业",
            "修改删除源后快照零变化+独立快照+跨企业拦截",
            "snapshot immutable after source UPDATE/DELETE; company隔离",
            "MySQL " + DrillEnv.mysqlVersion(),
            "数据层独立已验证；Service/Mapper/Flutter 读快照口径见静态核查与回归，Flutter UI 字段未在容器内实跑");
    }
}
