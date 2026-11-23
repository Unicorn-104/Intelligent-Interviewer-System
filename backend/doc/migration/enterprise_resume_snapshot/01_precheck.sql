-- =====================================================
-- 项目：Intelligent-Interviewer-System
-- 模块：E-App 企业投递简历独立存储
-- 文件用途：迁移前“真正只读”的全面预检；只使用 SELECT / information_schema，
--           不创建任何存储过程、不修改任何数据库对象
-- 执行环境：需由用户核实目标库（建议先在隔离/测试库演练，再在生产库执行）
-- 执行前提：当前账号对 information_schema 及业务表具备 SELECT 权限
-- 涉及数据表：t_app_record、t_tal、t_res_base、t_res_education、t_res_work、
--             t_res_project、t_res_skill、t_ai_candidate_analysis
-- 数据影响：纯只读（无 DDL / DML / 临时对象）
-- 是否可重复执行：是（纯 SELECT，可多次执行核对）
-- 回滚文件：无（只读，无需回滚）
-- 使用方式：逐项执行并人工核对“判定/预期”列；任一“需停止”项未澄清前，不得执行 02_schema.sql
-- 执行权限：仅用户审核批准后手动执行
-- =====================================================

-- -----------------------------------------------------
-- 【检查 1】目标企业快照表是否已存在（首次迁移应 0 行）
-- 若已存在，不能直接判定可迁移，需结合检查 12 核对表结构
-- -----------------------------------------------------
SELECT table_name AS '企业快照表(首次迁移应查不到)', table_type
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('t_ent_resume_snapshot', 't_ent_resume_education',
                     't_ent_resume_work', 't_ent_resume_project', 't_ent_resume_skill')
ORDER BY table_name;

-- -----------------------------------------------------
-- 【检查 2】迁移所依赖的既有表是否齐全（应见 8 行，缺任一即停止）
-- -----------------------------------------------------
SELECT table_name AS '依赖表(应全部存在)'
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN ('t_app_record', 't_tal', 't_res_base', 't_res_education',
                     't_res_work', 't_res_project', 't_res_skill', 't_ai_candidate_analysis')
ORDER BY table_name;

-- -----------------------------------------------------
-- 【检查 3】投递记录六态分布（确认 app_status 均落在合法 0..5）
-- 出现非法状态（-1 或 >5）需先人工核对，本脚本不修改六态
-- -----------------------------------------------------
SELECT COALESCE(app_status, -1) AS app_status,
       COUNT(*) AS cnt
FROM t_app_record
GROUP BY app_status
ORDER BY app_status;

-- -----------------------------------------------------
-- 【检查 4】缺失/异常简历引用分布（异常项迁移后只能“待核实”，禁止伪造）
-- -----------------------------------------------------
SELECT
  CASE
    WHEN a.app_resume_id IS NULL THEN '简历引用为空'
    WHEN b.rbs_id IS NULL THEN '引用简历已不存在'
    ELSE '引用正常'
  END AS missing_type,
  COUNT(*) AS cnt
FROM t_app_record a
LEFT JOIN t_res_base b ON b.rbs_id = a.app_resume_id
GROUP BY missing_type
ORDER BY missing_type;

-- -----------------------------------------------------
-- 【检查 5】引用简历软删状态分布（rbs_status=0 软删，文件引用可能已清空）
-- -----------------------------------------------------
SELECT COALESCE(b.rbs_status, -1) AS rbs_status,
       COUNT(*) AS cnt
FROM t_app_record a
LEFT JOIN t_res_base b ON b.rbs_id = a.app_resume_id
GROUP BY b.rbs_status
ORDER BY b.rbs_status;

-- -----------------------------------------------------
-- 【检查 6】同一候选人 + 岗位重复投递（cnt>1 即存在多条，需以 app_id 精确绑定）
-- -----------------------------------------------------
SELECT app_candidate_id, app_position_id, COUNT(*) AS cnt
FROM t_app_record
GROUP BY app_candidate_id, app_position_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC, app_candidate_id;

-- -----------------------------------------------------
-- 【检查 7】AI 分析来源分布（llm / manual / unknown）
-- -----------------------------------------------------
SELECT COALESCE(json_unquote(json_extract(asr_report, '$.source')), 'unknown') AS report_source,
       COUNT(*) AS cnt
FROM t_ai_candidate_analysis
GROUP BY report_source
ORDER BY report_source;

-- -----------------------------------------------------
-- 【检查 8】分析表全部索引明细（含 SUB_PART 前缀长度、列数、non_unique）
-- 供人工核对真实索引名称与结构；SUB_PART 非 NULL 即前缀索引
-- -----------------------------------------------------
SELECT index_name AS '分析表索引名',
       non_unique AS 'non_unique(0唯一)',
       COUNT(*) AS column_count,
       SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END) AS prefix_column_count,
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
GROUP BY index_name, non_unique
ORDER BY non_unique, index_name;

-- -----------------------------------------------------
-- 【检查 9】分析表必需字段是否齐全
-- 旧列应全部存在；新列若已存在说明部分迁移过，需结合检查 12/04_verify 核对
-- -----------------------------------------------------
SELECT column_name AS '分析表字段',
       column_type AS '字段类型',
       is_nullable AS '可空',
       CASE WHEN column_name IN (
              'asr_company_id','asr_position_id','asr_candidate_id','asr_resume_id',
              'asr_report','asr_updated_at')
            THEN '旧列(应存在)'
            WHEN column_name IN (
              'asr_app_id','asr_snapshot_id','asr_content_hash','asr_source',
              'asr_version_status','asr_created_at')
            THEN '新列(首次迁移可不存在)'
            ELSE '其他列(需人工确认)'
       END AS expected
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 't_ai_candidate_analysis'
ORDER BY ordinal_position;

-- -----------------------------------------------------
-- 【检查 10】非主键唯一索引逐项判定（关键人工守卫）
-- 判定“预期旧唯一索引(可删除)”应恰好 1 个或 0 个（重跑）；
-- 出现“非预期唯一索引(需停止)”时，禁止执行 02 的删除步骤
-- -----------------------------------------------------
SELECT index_name AS '唯一索引名',
       COUNT(*) AS column_count,
       SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END) AS prefix_column_count,
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns,
       CASE WHEN COUNT(*) = 3
             AND SUM(CASE WHEN SUB_PART IS NULL THEN 0 ELSE 1 END) = 0
             AND GROUP_CONCAT(column_name ORDER BY seq_in_index)
                 = 'asr_company_id,asr_position_id,asr_candidate_id'
            THEN '预期旧唯一索引(可删除)'
            ELSE '非预期唯一索引(需停止人工核对)'
       END AS verdict
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND non_unique = 0 AND index_name <> 'PRIMARY'
GROUP BY index_name
ORDER BY verdict, index_name;

-- -----------------------------------------------------
-- 【检查 11】目标普通索引同名冲突预检
-- 若同名索引已存在，显示其真实结构，供人工判断是否“同名异结构”；
-- 首次迁移通常 0 行，02 执行期会再次自动阻断同名异结构
-- -----------------------------------------------------
SELECT index_name AS '目标普通索引(已存在的同名项)',
       COUNT(*) AS column_count,
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 't_ai_candidate_analysis'
  AND index_name IN ('idx_asr_app','idx_asr_snapshot',
                     'idx_asr_company_candidate','idx_asr_company_position')
GROUP BY index_name
ORDER BY index_name;

-- -----------------------------------------------------
-- 【检查 12】若快照表已存在：核对主表字段与关键索引（防止“表名存在即认为结构正确”）
-- 12a 主表字段：预期字段缺失或类型不符需人工核对，不允许悄悄覆盖
-- -----------------------------------------------------
SELECT column_name AS '快照主表字段',
       column_type AS '字段类型',
       is_nullable AS '可空'
FROM information_schema.columns
WHERE table_schema = DATABASE() AND table_name = 't_ent_resume_snapshot'
ORDER BY ordinal_position;

-- 12b 主表关键索引（应含 uk_ers_app 唯一及 4 个普通 idx_*）
SELECT index_name AS '快照主表索引',
       non_unique AS 'non_unique(0唯一)',
       GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns
FROM information_schema.statistics
WHERE table_schema = DATABASE() AND table_name = 't_ent_resume_snapshot'
GROUP BY index_name, non_unique
ORDER BY index_name;

-- =====================================================
-- 人工预检结论（全部满足才进入 02_schema.sql）：
--   1) 检查2 依赖表 8 行齐全；检查3 无非法六态
--   2) 检查10 “可删除”旧唯一索引为 0 或 1 个，且无“需停止”项
--   3) 检查11 无同名异结构（若有同名，需确认结构与目标一致）
--   4) 检查4/5 的异常引用数量已记录，迁移后保持“待核实”
--   5) 若检查1 显示快照表已存在，必须用检查12 与 04_verify.sql 核对结构
-- 说明：本文件仅做只读检查，不代表真实 MySQL 已执行迁移；
--       DDL 隐式提交、无法整体事务回滚，相关执行期保护见 02_schema.sql。
-- =====================================================
