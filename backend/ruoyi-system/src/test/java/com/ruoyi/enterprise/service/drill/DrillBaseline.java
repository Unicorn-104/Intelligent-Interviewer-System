package com.ruoyi.enterprise.service.drill;

/**
 * 演练基线：把任意干净（或已被使用）的容器重置到“源表+种子已就位、02 结构迁移完成、尚无快照数据”的状态。
 * 每个场景类在 @BeforeAll 调用，保证独立可跑、结果可复现；不依赖跨类执行顺序。
 */
final class DrillBaseline
{
    private DrillBaseline() {}

    /** 场景 A 基础种子（脱敏占位）。 */
    static final String SEED = """
        INSERT INTO t_pos (pos_id, pos_company_id, pos_name) VALUES (10, 9, '岗位X');
        INSERT INTO t_tal (tal_id, tal_user_id, tal_company_id) VALUES (50, 500, 9), (51, 501, 9);
        INSERT INTO t_res_base (rbs_id, rbs_user_id, rbs_resume_name, rbs_job_direction,
            rbs_file_path, rbs_file_name, rbs_file_size, rbs_status)
          VALUES (1, 500, '简历甲', '后端', 'private-resume/50/2026/01/01/aaa.pdf', 'aaa.pdf', 1234, 1);
        INSERT INTO t_app_record (app_id, app_candidate_id, app_position_id, app_resume_id,
            app_status, app_created_at)
          VALUES (1001, 50, 10, 1, 1, '2026-01-05 10:00:00'),
                 (1002, 51, 10, NULL, 0, '2026-02-05 10:00:00');
        INSERT INTO t_res_education (edu_resume_id, edu_school, edu_major, edu_degree,
            edu_start_date, edu_end_date, edu_gpa, edu_description)
          VALUES (1, '贵州大学', '软件工程', 3, '2023-09-01', '2027-06-30', 3.50, '课程');
        INSERT INTO t_res_work (wrk_resume_id, wrk_company, wrk_position, wrk_department,
            wrk_start_date, wrk_end_date, wrk_is_current, wrk_salary_range, wrk_description)
          VALUES (1, '公司A', '工程师', '研发部', '2025-07-01', NULL, 1, '8k', '业绩');
        INSERT INTO t_res_project (prj_resume_id, prj_name, prj_role, prj_start_date,
            prj_end_date, prj_description, prj_tech_stack)
          VALUES (1, '项目P', '后端', '2025-08-01', '2025-10-01', '描述', 'Java,Spring');
        INSERT INTO t_res_skill (skl_resume_id, skl_name, skl_level)
          VALUES (1, 'Java', 3), (1, 'Python', 2);
        INSERT INTO t_ai_candidate_analysis (asr_company_id, asr_position_id, asr_candidate_id,
            asr_resume_id, asr_report, asr_updated_at)
          VALUES (9, 10, 50, 1, JSON_OBJECT('source','llm','score',80), '2026-01-06 10:00:00');
        """;

    private static final String CLEANUP = """
        DROP TABLE IF EXISTS t_ent_resume_skill, t_ent_resume_project, t_ent_resume_work,
          t_ent_resume_education, t_ent_resume_snapshot, t_ai_candidate_analysis,
          t_res_skill, t_res_project, t_res_work, t_res_education, t_res_base,
          t_app_record, t_tal, t_pos;
        """;

    /** 重置并建到结构迁移完成（过程已定义，未回填）。 */
    static void setup() throws Exception
    {
        DrillEnv.executeScript(CLEANUP);
        DrillEnv.runResource("drill/drill_source_schema.sql");
        DrillEnv.executeScript(SEED);
        DrillEnv.executeScript(DrillMigration.load("01_precheck.sql"));
        DrillEnv.executeScript(DrillMigration.load("02_schema.sql"));
        DrillEnv.executeScript("CALL p_ent_preflight_guard()");
        DrillEnv.executeScript("CALL p_ent_schema_migrate()");
    }
}
